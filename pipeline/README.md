# AI Pipeline（本機版，取代 Symphony）

用本機 HTML dashboard 驅動 `WORKFLOW.md` 的需求開發流程：貼上 Jira 連結 → AI 產出 SA/SD spec → 在網頁上 review → AI 實作 → push → 交接 RD。

## 架構

```
瀏覽器 http://127.0.0.1:4000
   │  (ui/index.html)
   ▼
pipeline/server.py ──輪詢──▶ Jira REST（pipeline/bin/jira）
   │ 每張 ticket 一個 git worktree：~/code/ai-demo-workspaces/<KEY>
   │ 以 WORKFLOW.md + workflows/_feature|_bug.md 渲染 prompt
   ▼
claude -p（stream-json）──寫出訊號檔──▶ <worktree>/.pipeline/
      discussion_request.json → dashboard 顯示「待審核」
      handoff.json            → 已交接 RD
      blocked.json            → 卡住，需人工
   ◀── review 送出後 server 寫入 spec_decision.json / spec_comments/ 並重新派發
```

| Symphony | 本機版 |
|----------|--------|
| WORKFLOW.md YAML front matter | `pipeline/config.json` |
| `.symphony/bin/jira` | `pipeline/bin/jira`（自動加入 agent 的 PATH） |
| `ai_pipeline` label 過濾 | 在 dashboard 貼 Jira 連結加入 |
| `.symphony/discussion_request.json` + LiveView | `.pipeline/discussion_request.json` + dashboard Review 分頁 |
| `--label symphony` | `--label ai-pipeline` |
| 移除 `ai_pipeline` label 結束輪詢 | agent 寫 `.pipeline/handoff.json` |

## 第一次設定

1. **Jira 憑證**：在 repo 根目錄 `.env` 或 `pipeline/.env`（兩者都已 git-ignore）補齊：
   ```
   JIRA_ENDPOINT=https://<site>.atlassian.net
   JIRA_EMAIL=<你的 Atlassian 帳號 email>
   JIRA_API_TOKEN=<token>        # 也接受 JIRA_TOKEN
   ```
   驗證：`pipeline/bin/jira get /rest/api/3/myself`
2. **GitHub remote 與初始 commit**（worktree 需要 base branch 已存在；agent 需要 push）：
   ```bash
   git add -A && git commit -m "chore: add AI pipeline workflow"
   gh repo create <name> --private --source . --push     # 或 git remote add origin ... && git push -u origin develop
   ```
   `.claude/`、`WORKFLOW.md`、`workflows/` 必須 commit，worktree 內的 agent 才看得到 agents/skills。
3. **gh 登入**：`gh auth status`（bug 流程會開 PR）。

## 啟動

```bash
python3 pipeline/server.py
# 開啟 http://127.0.0.1:4000
```

- 貼 Jira 連結（或 key）→ 加入。狀態在 `active_states` 內就會派發。
- **即時 Log**：agent 的文字、工具呼叫與結果。
- **Review**：spec 渲染後每個標題旁有「💬 留言」，加上整體意見 → Approve / Request changes / Reject。草稿存在瀏覽器，送出前不會遺失。
- **Git**：worktree 的 branch、commits、diff stat。**Prompt**：下次派發的完整 prompt。
- 自動輪詢：Jira 狀態變更（例如 RD 把 ticket 移到 `Code Review`、`Rework`）時自動重新派發。

## 設定（pipeline/config.json）

| 欄位 | 說明 |
|------|------|
| `tracker.active_states` / `terminal_states` | 對應你 Jira board 的狀態名稱（比對時忽略大小寫與空白） |
| `tracker.recheck_states` | 這些狀態（預設 `Code Review`）閒置時會每 `recheck_interval_ms` 重新檢查 CI |
| `repo.base_branch` | 預設 `develop` |
| `agent.max_continuations` | 狀態沒推進時自動續跑次數 |
| `claude_code.permission_args` | 預設 `acceptEdits` + `.claude/settings.json` 白名單。若 log 常出現權限被拒而卡住，可改成 `["--permission-mode", "bypassPermissions"]`（風險：agent 可執行任何指令） |
| `env.DEVELOPER_DIR` | 因 `xcode-select` 指向 CommandLineTools，這裡指定 Xcode 26.2 |

## 手動模式

不透過 server、直接在 repo 開 `claude` 也能跑這個流程（`LAUNCH_MODE=manual`）：review 點會在聊天中停下，由你回覆 `approve` / `request_changes` / `reject`。
