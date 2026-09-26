#!/usr/bin/env python3
"""Local AI pipeline orchestrator (replaces Symphony).

- Serves the dashboard at http://127.0.0.1:<port>/ (pipeline/ui/index.html)
- Tickets are added by pasting a Jira link; no label filter.
- Dispatches `claude -p` per ticket in an isolated git worktree, streams logs,
  surfaces review halts (.pipeline/discussion_request.json) and writes the
  reviewer's verdict back into the workspace before re-dispatching.

Only Python 3 stdlib is required. Run:  python3 pipeline/server.py
"""
import importlib.machinery
import importlib.util
import json
import os
import re
import shutil
import signal
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PIPELINE_DIR = Path(__file__).resolve().parent
REPO_ROOT = PIPELINE_DIR.parent
STATE_DIR = PIPELINE_DIR / "state"
TICKETS_FILE = STATE_DIR / "tickets.json"
LOG_DIR = STATE_DIR / "logs"
UI_FILE = PIPELINE_DIR / "ui" / "index.html"
WORKFLOW_FILE = REPO_ROOT / "WORKFLOW.md"
FLOWS_DIR = REPO_ROOT / "workflows"
SIGNAL_DIR = ".pipeline"  # inside each workspace

KEY_RE = re.compile(r"\b([A-Z][A-Z0-9_]+-\d+)\b")

# Reuse the Jira CLI as a module (it has no .py extension).
_loader = importlib.machinery.SourceFileLoader("jira_cli", str(PIPELINE_DIR / "bin" / "jira"))
_spec = importlib.util.spec_from_loader("jira_cli", _loader)
jira = importlib.util.module_from_spec(_spec)
_loader.exec_module(jira)
jira.load_env()


def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")


def load_config():
    return json.loads((PIPELINE_DIR / "config.json").read_text())


CONFIG = load_config()
LOCK = threading.RLock()
TICKETS = {}      # key -> ticket dict (persisted)
PROCS = {}        # key -> {"proc": Popen, "run_id": str, "last_output": float, "stop": bool}
POLL = {"enabled": CONFIG["polling"].get("enabled", True), "last_poll": 0.0}


# ---------------------------------------------------------------- persistence

def save():
    with LOCK:
        STATE_DIR.mkdir(parents=True, exist_ok=True)
        tmp = TICKETS_FILE.with_suffix(".tmp")
        tmp.write_text(json.dumps(TICKETS, ensure_ascii=False, indent=2))
        tmp.replace(TICKETS_FILE)


def load():
    if TICKETS_FILE.exists():
        TICKETS.update(json.loads(TICKETS_FILE.read_text()))
    # Runs that were alive when the server died are gone now.
    for t in TICKETS.values():
        if t.get("local_state") == "running":
            t["local_state"] = "idle"
            t["note"] = "server 重啟時中斷，請手動繼續"


def log_line(key, run_id, text):
    d = LOG_DIR / key
    d.mkdir(parents=True, exist_ok=True)
    with open(d / f"{run_id}.log", "a", encoding="utf-8") as f:
        f.write(f"[{datetime.now().strftime('%H:%M:%S')}] {text}\n")


# ---------------------------------------------------------------- jira

def jira_call(fn, *args):
    try:
        return fn(*args), None
    except SystemExit:
        return None, "Jira 請求失敗（請檢查 pipeline/.env 的 JIRA_* 設定，詳細錯誤見 server 輸出）"
    except Exception as e:  # network etc.
        return None, str(e)


def fetch_issue(key):
    data, err = jira_call(jira.get_issue, key)
    if err:
        return None, err
    f = data.get("fields", {})
    endpoint = os.environ.get("JIRA_ENDPOINT", "").rstrip("/")
    return {
        "id": data.get("id"),
        "key": data.get("key"),
        "title": f.get("summary", ""),
        "issue_type": (f.get("issuetype") or {}).get("name", ""),
        "status": (f.get("status") or {}).get("name", ""),
        "labels": f.get("labels", []),
        "assignee": (f.get("assignee") or {}).get("displayName"),
        "description": jira.adf_to_text(f.get("description")).strip(),
        "url": f"{endpoint}/browse/{data.get('key')}",
    }, None


def norm(s):
    return (s or "").lower().replace(" ", "")


def is_active(status):
    return norm(status) in {norm(s) for s in CONFIG["tracker"]["active_states"]}


def is_terminal(status):
    return norm(status) in {norm(s) for s in CONFIG["tracker"]["terminal_states"]}


def refresh_ticket(key):
    issue, err = fetch_issue(key)
    with LOCK:
        t = TICKETS.get(key)
        if not t:
            return
        if err:
            t["jira_error"] = err
        else:
            t["jira_error"] = None
            t["issue"] = issue
            t["jira_status"] = issue["status"]
        save()


# ---------------------------------------------------------------- templating

IF_RE = re.compile(r"{%-?\s*if\s+(not\s+)?([\w.]+)\s*-?%}(.*?)(?:{%-?\s*else\s*-?%}(.*?))?{%-?\s*endif\s*-?%}", re.S)
VAR_RE = re.compile(r"{{\s*([\w.]+)\s*}}")
INCLUDE_RE = re.compile(r"{%-?\s*include\s+\"(\w+)\"\s*-?%}")


def lookup(ctx, dotted):
    cur = ctx
    for part in dotted.split("."):
        if isinstance(cur, dict):
            cur = cur.get(part)
        else:
            return None
    return cur


def render(template, ctx):
    def inc(m):
        name = ctx["flow"] if m.group(1) == "flow" else m.group(1)
        return (FLOWS_DIR / f"_{name}.md").read_text()

    out = INCLUDE_RE.sub(inc, template)

    def cond(m):
        neg, name, yes, no = m.group(1), m.group(2), m.group(3), m.group(4) or ""
        val = bool(lookup(ctx, name))
        return yes if val != bool(neg) else no

    out = IF_RE.sub(cond, out)

    def var(m):
        v = lookup(ctx, m.group(1))
        if isinstance(v, list):
            return ", ".join(map(str, v))
        return "" if v is None else str(v)

    return VAR_RE.sub(var, out)


def format_history(t):
    rounds = t.get("discussion_history", [])
    if not rounds:
        return ""
    lines = []
    for i, r in enumerate(rounds, 1):
        lines.append(f"### Round {i} — {r['type']} ({r['at']})")
        lines.append(f"- Question: {r.get('question', '')}")
        lines.append(f"- **Decision: {r['decision']}**")
        if r.get("overview"):
            lines.append(f"- Overview comment: {r['overview']}")
        for c in r.get("comments", []):
            lines.append(f"- Block comment `{c['block_id']}` ({c.get('heading', '')}): {c['text']}")
        lines.append(f"- Decision file: `{SIGNAL_DIR}/{r['decision_file']}`; comments dir: `{SIGNAL_DIR}/{r['comments_dir']}/`")
        lines.append("")
    return "\n".join(lines)


def build_prompt(t):
    issue = dict(t.get("issue") or {})
    is_bug = norm(issue.get("issue_type")) == "bug"
    issue["identifier"] = t["key"]
    issue["state"] = t.get("jira_status", "")
    issue["is_bug"] = is_bug
    issue["branch"] = f"{'fix' if is_bug else 'feature'}/{t['key']}"
    ctx = {
        "issue": issue,
        "attempt": t.get("attempt") or 0,
        "discussion_history": format_history(t),
        "flow": "bug" if is_bug else "feature",
        "workspace": t.get("workspace", ""),
        "base_branch": CONFIG["repo"]["base_branch"],
        "remote": CONFIG["repo"]["remote"],
    }
    return render(WORKFLOW_FILE.read_text(), ctx)


# ---------------------------------------------------------------- workspace

def hook_env(workspace):
    env = os.environ.copy()
    env.update({
        "REPO_ROOT": str(REPO_ROOT),
        "WORKSPACE": str(workspace),
        "REMOTE": CONFIG["repo"]["remote"],
        "BASE_BRANCH": CONFIG["repo"]["base_branch"],
    })
    return env


def ensure_workspace(key):
    root = Path(os.path.expanduser(CONFIG["workspace"]["root"]))
    ws = root / key
    if not ws.exists():
        root.mkdir(parents=True, exist_ok=True)
        r = subprocess.run(["bash", "-c", CONFIG["hooks"]["after_create"]], cwd=REPO_ROOT,
                           env=hook_env(ws), capture_output=True, text=True)
        if r.returncode != 0 or not ws.exists():
            raise RuntimeError(f"after_create hook 失敗：{r.stderr.strip() or r.stdout.strip()}")
    (ws / SIGNAL_DIR).mkdir(exist_ok=True)
    return ws


def remove_workspace(key):
    ws = Path(TICKETS[key].get("workspace") or "")
    if ws and ws.exists():
        subprocess.run(["bash", "-c", CONFIG["hooks"]["before_remove"]], cwd=REPO_ROOT,
                       env=hook_env(ws), capture_output=True, text=True)
        if ws.exists():
            shutil.rmtree(ws, ignore_errors=True)


# ---------------------------------------------------------------- agent runs

def summarize_tool_input(name, inp):
    if not isinstance(inp, dict):
        return ""
    for k in ("command", "file_path", "pattern", "path", "url", "description", "prompt", "skill"):
        if k in inp:
            return str(inp[k]).replace("\n", " ")[:240]
    return json.dumps(inp, ensure_ascii=False)[:240]


def handle_stream_line(key, run_id, line):
    try:
        ev = json.loads(line)
    except json.JSONDecodeError:
        log_line(key, run_id, line.rstrip()[:500])
        return
    typ = ev.get("type")
    if typ == "system" and ev.get("subtype") == "init":
        log_line(key, run_id, f"⚙️ session {ev.get('session_id')} model={ev.get('model')}")
    elif typ == "assistant":
        for block in ev.get("message", {}).get("content", []):
            if block.get("type") == "text" and block.get("text", "").strip():
                log_line(key, run_id, "💬 " + block["text"].strip())
            elif block.get("type") == "tool_use":
                log_line(key, run_id, f"🔧 {block.get('name')}: {summarize_tool_input(block.get('name'), block.get('input'))}")
    elif typ == "user":
        for block in ev.get("message", {}).get("content", []):
            if isinstance(block, dict) and block.get("type") == "tool_result":
                content = block.get("content")
                if isinstance(content, list):
                    content = " ".join(c.get("text", "") for c in content if isinstance(c, dict))
                text = str(content or "").strip().replace("\n", " ⏎ ")
                prefix = "   ↳ ❌ " if block.get("is_error") else "   ↳ "
                log_line(key, run_id, prefix + text[:300])
    elif typ == "result":
        log_line(key, run_id, f"🏁 {ev.get('subtype')} turns={ev.get('num_turns')} cost=${ev.get('total_cost_usd', 0):.2f}")
        if ev.get("result"):
            log_line(key, run_id, "📋 " + str(ev["result"]).strip())


def agent_env(key):
    env = os.environ.copy()
    env.update(CONFIG.get("env", {}))
    env["PATH"] = f"{PIPELINE_DIR / 'bin'}:{env.get('PATH', '')}"
    env["AI_PIPELINE"] = "1"
    env["AI_PIPELINE_TICKET"] = key
    return env


def dispatch(key):
    with LOCK:
        t = TICKETS[key]
        t["local_state"] = "running"
        t["note"] = None
        save()
    try:
        ws = ensure_workspace(key)
    except Exception as e:
        with LOCK:
            t["local_state"] = "error"
            t["note"] = str(e)
            save()
        return
    with LOCK:
        t["workspace"] = str(ws)
        prompt = build_prompt(t)
        (ws / SIGNAL_DIR / "prompt.md").write_text(prompt)
        for stale in ("discussion_request.json", "handoff.json", "blocked.json"):
            (ws / SIGNAL_DIR / stale).unlink(missing_ok=True)
        run_id = datetime.now().strftime("%Y%m%d-%H%M%S")
        t.setdefault("runs", []).append({"id": run_id, "started": now_iso(), "status_at_start": t.get("jira_status"),
                                         "attempt": t.get("attempt", 0)})
        t["last_dispatch_status"] = t.get("jira_status")
        save()

    agent = CONFIG["agent"]
    cc = CONFIG["claude_code"]
    cmd = [cc["command"], "-p", "--output-format", "stream-json", "--verbose",
           "--model", agent["model"], "--max-turns", str(agent["max_turns"]),
           *cc.get("permission_args", []), *cc.get("extra_args", [])]
    log_line(key, run_id, f"▶️ dispatch {key} status={t.get('jira_status')} attempt={t.get('attempt', 0)} ws={ws}")
    proc = subprocess.Popen(cmd, cwd=ws, env=agent_env(key), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, text=True, bufsize=1, start_new_session=True)
    proc.stdin.write(prompt)
    proc.stdin.close()
    PROCS[key] = {"proc": proc, "run_id": run_id, "last_output": time.time(), "stop": False}
    threading.Thread(target=reader, args=(key, run_id, proc), daemon=True).start()


def reader(key, run_id, proc):
    for line in proc.stdout:
        PROCS[key]["last_output"] = time.time()
        handle_stream_line(key, run_id, line)
    code = proc.wait()
    finish_run(key, run_id, code)


def read_signal(ws, name):
    p = Path(ws) / SIGNAL_DIR / name
    if not p.exists():
        return None
    try:
        data = json.loads(p.read_text() or "{}")
    except json.JSONDecodeError:
        data = {"raw": p.read_text()}
    archive = Path(ws) / SIGNAL_DIR / "history"
    archive.mkdir(exist_ok=True)
    p.rename(archive / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{name}")
    return data


def finish_run(key, run_id, code):
    info = PROCS.pop(key, {})
    refresh_ticket(key)
    with LOCK:
        t = TICKETS[key]
        ws = t.get("workspace")
        run = t["runs"][-1]
        run.update({"ended": now_iso(), "exit": code})
        request = read_signal(ws, "discussion_request.json")
        handoff = read_signal(ws, "handoff.json")
        blocked = read_signal(ws, "blocked.json")
        if info.get("stop"):
            t["local_state"], t["note"] = "stopped", "已手動停止"
        elif request:
            request.setdefault("type", "spec_review")
            request["at"] = now_iso()
            # A new review round invalidates the previous verdict for the same review type.
            old = Path(ws) / SIGNAL_DIR / f"{request['type'].replace('_review', '')}_decision.json"
            if old.exists():
                old.rename(Path(ws) / SIGNAL_DIR / "history" / f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{old.name}")
            t["review"] = request
            t["local_state"], t["note"] = "awaiting_review", request.get("question")
        elif blocked:
            t["local_state"], t["note"] = "blocked", blocked.get("reason") or json.dumps(blocked, ensure_ascii=False)
        elif handoff:
            t["local_state"], t["note"] = "handed_off", handoff.get("summary") or "已交接給 RD"
            t["attempt"] = 0
        elif is_terminal(t.get("jira_status")):
            t["local_state"], t["note"] = "done", f"Jira 狀態 {t.get('jira_status')}"
        elif t.get("jira_status") != run.get("status_at_start"):
            t["local_state"], t["note"] = "queued", f"Jira 狀態變更為 {t.get('jira_status')}，繼續下一階段"
            t["attempt"] = 0
        elif code == 0 and t.get("attempt", 0) < CONFIG["agent"]["max_continuations"]:
            t["attempt"] = t.get("attempt", 0) + 1
            t["local_state"], t["note"] = "queued", f"狀態未變更，自動續跑 attempt #{t['attempt']}"
        else:
            t["local_state"] = "idle"
            t["note"] = f"agent 結束（exit {code}），狀態未推進，請看 log 後手動繼續"
        run["outcome"] = t["local_state"]
        save()
    log_line(key, run_id, f"⏹ exit={code} → {TICKETS[key]['local_state']}: {TICKETS[key].get('note') or ''}")


def stop_run(key):
    info = PROCS.get(key)
    if info:
        info["stop"] = True
        try:
            os.killpg(info["proc"].pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


# ---------------------------------------------------------------- scheduler

def scheduler():
    while True:
        time.sleep(2)
        try:
            tick()
        except Exception as e:  # keep the loop alive
            print(f"[scheduler] {e}")


def tick():
    now = time.time()
    stall = CONFIG["agent"]["stall_timeout_ms"] / 1000
    for key, info in list(PROCS.items()):
        if now - info["last_output"] > stall:
            log_line(key, info["run_id"], f"⏱ {int(stall)}s 無輸出，視為卡住並終止")
            try:
                os.killpg(info["proc"].pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    if POLL["enabled"] and now - POLL["last_poll"] > CONFIG["polling"]["interval_ms"] / 1000:
        POLL["last_poll"] = now
        with LOCK:
            keys = [k for k, t in TICKETS.items() if t.get("local_state") not in ("done", "running")]
        for key in keys:
            refresh_ticket(key)
        with LOCK:
            for key in keys:
                t = TICKETS[key]
                status = t.get("jira_status")
                if is_terminal(status):
                    t["local_state"], t["note"] = "done", f"Jira 狀態 {status}"
                elif t.get("local_state") in ("idle", "handed_off", "blocked") and status != t.get("last_dispatch_status") and is_active(status):
                    t["local_state"], t["attempt"] = "queued", 0
                    t["note"] = f"偵測到 Jira 狀態變更為 {status}"
                elif (t.get("local_state") in ("idle", "handed_off") and norm(status) in {norm(s) for s in CONFIG["tracker"]["recheck_states"]}
                      and t.get("runs") and now - datetime.fromisoformat(t["runs"][-1].get("ended", t["runs"][-1]["started"])).timestamp()
                      > CONFIG["tracker"]["recheck_interval_ms"] / 1000):
                    t["local_state"], t["note"] = "queued", f"{status} 定期重新檢查"
            save()

    with LOCK:
        capacity = CONFIG["agent"]["max_concurrent_agents"] - len(PROCS)
        queued = sorted((t for t in TICKETS.values() if t.get("local_state") == "queued"), key=lambda t: t.get("added", ""))
        to_run = []
        for t in queued:
            if capacity <= 0:
                break
            if not is_active(t.get("jira_status")):
                t["note"] = f"Jira 狀態「{t.get('jira_status')}」不在 active_states，暫不派發"
                continue
            to_run.append(t["key"])
            capacity -= 1
    for key in to_run:
        dispatch(key)


# ---------------------------------------------------------------- review

def submit_review(key, body):
    decision = body.get("decision")
    if decision not in ("approve", "request_changes", "reject"):
        raise ValueError("decision 必須是 approve / request_changes / reject")
    with LOCK:
        t = TICKETS[key]
        review = t.get("review")
        if not review:
            raise ValueError("此 ticket 目前沒有待審項目")
        ws = Path(t["workspace"]) / SIGNAL_DIR
        prefix = review["type"].replace("_review", "")
        decision_file = f"{prefix}_decision.json"
        comments_dir = f"{prefix}_comments"
        at = now_iso()
        reviewer = body.get("reviewer") or "RD"
        (ws / decision_file).write_text(json.dumps({"decision": decision, "type": review["type"], "reviewer": reviewer,
                                                    "at": at}, ensure_ascii=False, indent=2))
        cdir = ws / comments_dir
        cdir.mkdir(exist_ok=True)
        comments = [c for c in body.get("comments", []) if c.get("text", "").strip()]
        entries = []
        if body.get("overview", "").strip():
            entries.append(("_overview", {"block_id": "_overview", "heading": "Overview", "text": body["overview"].strip()}))
        entries += [(c["block_id"], c) for c in comments]
        for block_id, c in entries:
            safe = re.sub(r"[^\w.-]", "_", block_id)[:120]
            p = cdir / f"{safe}.json"
            data = json.loads(p.read_text()) if p.exists() else {"block_id": block_id, "heading": c.get("heading"), "comments": []}
            data["comments"].append({"author": reviewer, "message": c["text"].strip(), "timestamp": at})
            p.write_text(json.dumps(data, ensure_ascii=False, indent=2))
        t.setdefault("discussion_history", []).append({
            "type": review["type"], "question": review.get("question"), "decision": decision,
            "overview": body.get("overview", "").strip(), "comments": comments, "at": at,
            "decision_file": decision_file, "comments_dir": comments_dir,
        })
        t["review"] = None
        t["local_state"], t["attempt"] = "queued", 0
        t["note"] = f"已送出 {decision}，重新派發 agent"
        save()


def safe_workspace_path(t, rel):
    ws = Path(t.get("workspace") or "").resolve()
    p = (ws / rel).resolve()
    if not t.get("workspace") or ws not in p.parents and p != ws:
        raise PermissionError("path outside workspace")
    return p


def git_summary(t):
    ws = t.get("workspace")
    if not ws or not Path(ws).exists():
        return {}
    base = f"{CONFIG['repo']['remote']}/{CONFIG['repo']['base_branch']}"

    def git(*args):
        r = subprocess.run(["git", *args], cwd=ws, capture_output=True, text=True)
        return r.stdout.strip()

    return {
        "branch": git("branch", "--show-current"),
        "head": git("log", "-1", "--format=%h %s"),
        "log": git("log", "--oneline", f"{base}..HEAD") or git("log", "--oneline", "-10"),
        "stat": git("diff", "--stat", f"{base}...HEAD"),
        "dirty": git("status", "--short"),
    }


# ---------------------------------------------------------------- http

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def send_json(self, obj, status=200):
        data = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def error(self, msg, status=400):
        self.send_json({"error": msg}, status)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")

    def ticket_or_404(self, key):
        t = TICKETS.get(key)
        if not t:
            self.error("ticket not found", 404)
        return t

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        parts = [p for p in u.path.split("/") if p]
        if u.path in ("/", "/index.html"):
            data = UI_FILE.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif u.path == "/api/state":
            with LOCK:
                self.send_json({"tickets": list(TICKETS.values()), "polling": POLL["enabled"],
                                "running": list(PROCS.keys()), "config": {
                                    "model": CONFIG["agent"]["model"], "base_branch": CONFIG["repo"]["base_branch"],
                                    "workspace_root": CONFIG["workspace"]["root"],
                                    "max_concurrent": CONFIG["agent"]["max_concurrent_agents"],
                                    "jira_endpoint": os.environ.get("JIRA_ENDPOINT", "")}})
        elif len(parts) == 4 and parts[:2] == ["api", "tickets"]:
            key, action = parts[2], parts[3]
            t = self.ticket_or_404(key)
            if not t:
                return
            if action == "log":
                runs = t.get("runs", [])
                run_id = q.get("run", [runs[-1]["id"] if runs else ""])[0]
                offset = int(q.get("offset", ["0"])[0])
                p = LOG_DIR / key / f"{run_id}.log"
                text = p.read_text(encoding="utf-8") if p.exists() else ""
                self.send_json({"run": run_id, "text": text[offset:], "offset": len(text)})
            elif action == "file":
                try:
                    p = safe_workspace_path(t, q.get("path", [""])[0])
                except PermissionError as e:
                    return self.error(str(e), 403)
                if not p.is_file():
                    return self.error("file not found", 404)
                ctype = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".gif": "image/gif",
                         ".svg": "image/svg+xml", ".json": "application/json", ".html": "text/plain"}.get(p.suffix.lower(), "text/plain; charset=utf-8")
                data = p.read_bytes()
                self.send_response(200)
                self.send_header("Content-Type", ctype)
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            elif action == "git":
                self.send_json(git_summary(t))
            elif action == "prompt":
                self.send_json({"prompt": build_prompt(t)})
            else:
                self.error("unknown action", 404)
        else:
            self.error("not found", 404)

    def do_POST(self):
        # Custom header blocks cross-site form posts (no CORS preflight allowed).
        if self.headers.get("X-Pipeline") != "1":
            return self.error("missing X-Pipeline header", 403)
        u = urlparse(self.path)
        parts = [p for p in u.path.split("/") if p]
        try:
            body = self.body()
        except json.JSONDecodeError:
            return self.error("invalid json")

        if u.path == "/api/tickets":
            url = body.get("url", "").strip()
            m = KEY_RE.search(url) or KEY_RE.search(url.upper())
            if not m:
                return self.error("找不到 Jira key（例如 SID-1234），請貼上 ticket 連結或 key")
            key = m.group(1)
            issue, err = fetch_issue(key)
            if err:
                return self.error(err, 502)
            with LOCK:
                if key in TICKETS:
                    return self.error(f"{key} 已在清單中", 409)
                TICKETS[key] = {"key": key, "added": now_iso(), "issue": issue, "jira_status": issue["status"],
                                "local_state": "queued" if body.get("autostart", True) else "idle",
                                "attempt": 0, "runs": [], "discussion_history": [], "review": None,
                                "note": None if body.get("autostart", True) else "已加入，按「開始」啟動"}
                save()
            return self.send_json(TICKETS[key])
        if u.path == "/api/polling":
            POLL["enabled"] = bool(body.get("enabled"))
            return self.send_json({"polling": POLL["enabled"]})
        if len(parts) == 4 and parts[:2] == ["api", "tickets"]:
            key, action = parts[2], parts[3]
            t = self.ticket_or_404(key)
            if not t:
                return
            if action == "start":
                if key in PROCS:
                    return self.error("已在執行中", 409)
                refresh_ticket(key)
                with LOCK:
                    t["local_state"], t["note"] = "queued", "手動啟動"
                    if body.get("reset_attempt", True):
                        t["attempt"] = 0
                    save()
                return self.send_json(t)
            if action == "stop":
                stop_run(key)
                with LOCK:
                    if key not in PROCS:
                        t["local_state"], t["note"] = "stopped", "已手動停止"
                        save()
                return self.send_json(t)
            if action == "refresh":
                refresh_ticket(key)
                return self.send_json(TICKETS[key])
            if action == "review":
                try:
                    submit_review(key, body)
                except ValueError as e:
                    return self.error(str(e))
                return self.send_json(TICKETS[key])
            if action == "delete":
                if key in PROCS:
                    return self.error("請先停止執行中的 agent", 409)
                with LOCK:
                    if body.get("remove_workspace"):
                        remove_workspace(key)
                    TICKETS.pop(key, None)
                    save()
                return self.send_json({"deleted": key})
        self.error("not found", 404)


def main():
    load()
    host, port = CONFIG["server"]["host"], CONFIG["server"]["port"]
    threading.Thread(target=scheduler, daemon=True).start()
    httpd = ThreadingHTTPServer((host, port), Handler)
    print(f"AI pipeline dashboard: http://{host}:{port}/")
    if not os.environ.get("JIRA_API_TOKEN"):
        print("⚠️  JIRA_API_TOKEN 未設定，請建立 pipeline/.env（參考 pipeline/.env.example）")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        for key in list(PROCS):
            stop_run(key)


if __name__ == "__main__":
    main()
