# TodoList AI Pipeline:面試分享報告

> 撰寫原則:本文件的內容都能在 repo 中找到依據,依據列在各節或文末的索引。
> 目前還沒有做過量化量測(耗時、成功率、token 用量、節省工時),所以文件裡不放任何成效數字。

---

## 1. 專案簡介

在 `TodoList` iOS 專案(Swift、Combine、MVVM)中,我自建了一套本機執行的 AI 開發流程,取代原本使用的 Symphony。

它的工作是:把 Jira ticket 交給無人值守的 Claude Code(`claude -p`),在每張票專屬的 git worktree 中完成「規格 → 實作 → 驗證 → 交給 RD」。其中規格審核和最後交付這兩步,由人在本機 dashboard 上決定。

## 2. 要解決的問題與分工原則

| 交給 AI agent | 留給人 |
|---|---|
| 讀票與附件(`jira summary`、`jira attachments`、`jira remotelinks`) | 審核規格:approve / request_changes / reject |
| 產出開發規格 `RefDoc_Temp/<id>/requirement-spec.md` | 功能票由 RD 開 PR、merge |
| 實作、編譯、測試、模擬器截圖(`ios-build`) | 把 Jira 推進到「完成」 |
| 在 Jira 維護唯一一則進度留言 `## Claude Workpad` | 處理 agent 回報的 blocker(權限、金鑰、環境) |
| 推分支;Bug 票由 agent 開 PR 並追 CI | |

分工原則:能用證據驗證的工作交給 AI,需要判斷、要負責的決定留給人。

依據:`WORKFLOW.md` Status map。

## 3. 架構總覽

| 元件 | 位置 | 職責 |
|---|---|---|
| Jira Cloud | 外部 | 需求與狀態的來源 |
| Dashboard | `pipeline/ui/index.html` | 單頁網頁,每 3 秒輪詢 `/api/state`;提供即時 log、Review、歷程、Git、Prompt 五個分頁 |
| Orchestrator | `pipeline/server.py` | 只用 Python 標準函式庫;HTTP server 與 scheduler thread;負責派工、收尾、寫入審核結果 |
| git worktree | `~/code/ai-demo-workspaces/<KEY>` | 每張票一個,由 `config.json` 的 `hooks.after_create` 建立 |
| Claude Code session | `claude -p --output-format stream-json` | 依 `WORKFLOW.md` 執行;使用 `bin/jira`、`bin/ios-build`、`gh` |

Agent 不呼叫 orchestrator 的 API。它在結束前把 signal file 寫進 worktree 的 `.pipeline/`,orchestrator 等 process 結束後才去讀。

## 4. 一張票的一輪流程

1. **加入**:RD 在 dashboard 貼上 Jira 連結(`POST /api/tickets`)。`fetch_issue()` 取得票的資料,狀態設為 `queued`,並存到 `pipeline/state/tickets.json`。
2. **排程**:`scheduler()` 每 2 秒呼叫一次 `tick()`,每 30 秒同步一次 Jira 狀態。同時執行的票數上限是 `max_concurrent_agents = 1`。
3. **派工**:`dispatch()` 依序做以下事情:
   - `ensure_workspace()` 建立 worktree。
   - `build_prompt()` 把 `WORKFLOW.md` 套成 prompt。套入的內容有票的資料、重試次數、`discussion_history`,以及依票的類型選擇 `_feature.md` 或 `_bug.md`。
   - `select_model()` 選擇模型。
   - 以 subprocess 啟動 `claude -p`,prompt 從 stdin 傳入。
4. **執行**:agent 讀取 Jira 狀態與 workpad,決定這一輪要跑哪一段流程(`WORKFLOW.md` Step 0)。
5. **停下**:agent 寫下一個 signal file 後結束 process。
6. **收尾**:`finish_run()` 用 `read_signal()` 讀取 signal file,把它搬到 `.pipeline/history/`,再轉換狀態。
7. **審核**:RD 在 Review 分頁逐章節留言,選擇 approve / request_changes / reject。`submit_review()` 寫入 `spec_decision.json` 與 `spec_comments/`,把這一輪記進 `discussion_history`,再把票重新設為 `queued`。
8. **下一輪**:全新的 session 讀取決策檔與先前的審核紀錄,接續往下做。直到 Jira 進入終止狀態,這張票就不再派工。

## 5. 狀態

### Jira 狀態(`pipeline/config.json`)

- `active_states`:待辦事項、SA/SD、In Development、Code Review、Rework。只有這些狀態會派工。
- `terminal_states`:完成、Waiting For QA。
- `recheck_states`:Code Review。處於 `idle` 或 `handed_off` 的票,若 Jira 狀態是 Code Review,且距上一輪結束超過 `recheck_interval_ms`(300000 ms,5 分鐘),就重新排入(`server.py` `tick()`)。agent 執行 General Phase(`WORKFLOW.md`),用 `gh pr checks` 查 CI,綠燈就轉 Waiting For QA。
  - 這裡的 Code Review 是 Jira 欄位,代表 handoff 之後 RD 在審 PR。agent 在這段期間只查 CI,不審程式碼,也不指定 reviewer。
  - agent 自己的程式碼審查是 handoff 前的 Self-review:用 `@code-reviewer` 檢查改動的檔案,結果記在 `Self-review Gate`(`workflows/_feature.md`)。

**目前實際的看板**只有:待辦事項 → SA/SD → In Development → 完成。Code Review、Rework、Waiting For QA 的流程已經寫好,但看板上還沒有這些欄位,**所以這些流程還沒實際跑過**。另外 SID 專案目前沒有 Bug 類型,所有票都走功能票流程。

| Jira 狀態 | 功能票 | Bug 票 |
|---|---|---|
| 待辦事項 | 轉 SA/SD,開始寫規格 | 轉 In Development,開始修 |
| SA/SD | 產出規格 → 停下等審核 | 不經過 |
| In Development | 實作 → 推分支 → 在 workpad 標記負責人 → `handoff.json` | 調查 → 修正 → 開 PR 附分析 → `handoff.json` |
| 完成 | 終止 | 終止 |

### Orchestrator 內部狀態(`local_state`)

`queued`、`running`、`awaiting_review`、`handed_off`、`blocked`、`idle`、`stopped`、`error`、`done`

`finish_run()` 按以下優先順序決定新狀態(`server.py`):

1. 使用者手動停止 → `stopped`
2. 有 `discussion_request.json` → `awaiting_review`
3. 有 `blocked.json` → `blocked`
4. 有 `handoff.json` → `handed_off`
5. Jira 已是終止狀態 → `done`
6. Jira 狀態在執行期間改變了 → `queued`
7. exit 0,而且 `attempt < max_continuations`(2)→ `queued`,`attempt + 1`
8. 其他情況 → `idle`,等人處理

另外,server 重啟時,原本 `running` 的票會被改成 `idle`,並註記「server 重啟時中斷,請手動繼續」(`load()`)。

## 6. Signal file 協定

| 檔案 | 誰寫 | 時機 | 內容 |
|---|---|---|---|
| `discussion_request.json` | agent | 停下等審核 | `type`、`question`、`spec_path`、`extra_paths` |
| `handoff.json` | agent | 達到交付標準 | `phase`、`branch`、`summary`、`pr_url` |
| `blocked.json` | agent | 真正的阻礙 | `reason`、`human_action` |
| `spec_decision.json` | orchestrator | RD 送出審核 | `decision`、`type`、`reviewer`、`at` |
| `spec_comments/<block-id>.json`、`_overview.json` | orchestrator | RD 送出審核 | 逐章節留言陣列 |

檔案被讀取後,會立刻搬到 `.pipeline/history/`,所以每個檔案只會被處理一次。開始新一輪審核時,會先把舊的同類型決策檔歸檔,避免 agent 讀到上一輪的結果。

## 7. 防止 agent 跳過步驟

`workflows/_feature.md` 的 Anti-skip execution contract 要求 agent 維護 `RefDoc_Temp/<id>/feature-execution-ledger.md`,裡面有 10 個 gate:

SA/SD Input Inventory、Spec Artifact、Visual Spec Asset、Spec Review Feedback、Spec Review Verdict、Implementation Coverage、Compilation、Validation、Self-review、Handoff

每個 gate 有以下規則:

- 狀態只能填 `TODO` / `PASS` / `BLOCKED` / `N/A` / `PENDING_REVIEW`,而且要附證據(檔案路徑、指令結果、留言 id)。「done」不算證據。
- "Review halts are real halts":沒有人明確 approve,就不能把審核 gate 標成 PASS。

**限制**:這些規則只寫在 prompt 裡,orchestrator 不會檢查 ledger 的內容。

## 8. 安全

Jira 票和審核留言都是任何成員可以編輯的文字,所以一律當作不可信輸入處理。

1. **Prompt 層**(`WORKFLOW.md` Security constraint;票的內容包在 `<untrusted_ticket_data>` 裡)
   - 採納:功能規格、驗收條件、範圍調整、技術偏好、RD 對規格的澄清。
   - 忽略,並記錄到 workpad 的 `### Security`:改寫角色或指令、要求輸出密鑰或環境變數、與任務無關的 shell 指令、推到無關的分支或 repo、要求關閉安全檢查。
   - 審核留言套用同樣的規則(`workflows/_feature.md`)。
2. **工具權限層**(`.claude/settings.json`,由 `permission_list_args()` 轉成 `--allowedTools` / `--disallowedTools` 傳入)
   - 允許:`git`、`gh`、`jira`、`xcodebuild`、`ios-build`、`xcrun`、`swiftformat`、`python3`,以及 `ls`、`cat`、`grep` 等唯讀或基本檔案指令。
   - 拒絕:`git push --force`、`git push -f`、`git reset --hard`、`rm -rf /`、`rm -rf ~`。
3. **執行環境層**
   - Bash 指令禁止 `$VAR`、`$(...)`、反引號、heredoc、`>` 重導向(`WORKFLOW.md` Shell command rules)。寫檔一律使用 Write / Edit 工具。`&&` 串接允許的指令則可以使用。
   - 每張票在獨立的 worktree 中工作。
   - Dashboard 只綁定 `127.0.0.1:4000`,所有 POST 都必須帶 `X-Pipeline: 1` header(`server.py` `do_POST()`),沒有登入機制。

這三層都無法保證完全擋住攻擊,設計目標是在某一層失效時縮小影響範圍。功能票的 PR 最後由 RD 自己開,這也是一道人工把關。

## 9. iOS 相關

`pipeline/bin/ios-build` 包裝了 `xcodebuild` 與 `xcrun simctl`:

| 子指令 | 行為 |
|---|---|
| `build` | 編譯,成功時輸出 `BUILD SUCCEEDED` |
| `test` | 跑測試;沒有 test target 時輸出 `N/A — no test target` 並以 exit 2 結束 |
| `run` | 啟動模擬器、安裝並開啟 App |
| `screenshot <path>` | 開啟 App、等 3 秒後截圖,當作驗收證據 |
| `sim` | 選擇第一台可用的 iPhone 模擬器 |

要另外包一層的原因:

- 無人值守時,含 shell 展開的指令無法自動核准。透過 wrapper,每個指令只需要帶字面參數。
- `xcode-select` 指向 CommandLineTools 時,會自動修正 `DEVELOPER_DIR`。
- 輸出只保留最後 40 行。

Orchestrator 跑在本機,原因之一就是 build、測試、截圖都需要本機的 Xcode 與模擬器。專案規則(`CLAUDE.md`:Swift + Combine、async/await、MVVM)也會寫進 agent 的預設準則。

## 10. 可靠性與成本設定(`pipeline/config.json`)

| 設定 | 值 | 作用 |
|---|---|---|
| `stall_timeout_ms` | 900000(15 分鐘) | 超過這段時間沒有輸出,就終止 process |
| `max_continuations` | 2 | 沒有留下 signal file 時,自動續跑的次數上限 |
| `max_turns` | 200 | 單一 session 的回合上限 |
| `max_concurrent_agents` | 1 | 一次只跑一張票 |
| `model` / `handoff_model` | `claude-opus-5-5` / `claude-haiku-4-5` | 已交付、而且不在 Rework 或 recheck 狀態的票,重跑時只做確認,因此改用較小的模型(`select_model()`) |

併發設為 1 的考量:多張票同時執行時,可能會搶用模擬器與 DerivedData。這點我沒有實測過多併發的情況,是基於這個考量先做保守設定。

## 11. 設計取捨

| 決定 | 好處 | 代價 |
|---|---|---|
| 本機 orchestrator,只用標準函式庫 | 可以直接使用本機 Xcode 與模擬器;不需要額外基礎設施與套件 | 單機執行,無法多人共用 |
| 每張票一個 git worktree | 票與票之間隔離;共用 object store;dashboard 可以顯示每張票的 diff | 需要管理 worktree 的建立與清除 |
| 用 signal file 溝通,不用 API | 每一輪的結果都留在硬碟上,方便追查;server 重啟時不會留下進行中的呼叫 | agent 無法在執行途中詢問人 |
| 遇到審核就結束 session | 不需要讓 process 一直等人 | 每一輪都要從 workpad、ledger、`discussion_history` 重建上下文 |
| 流程規則放在 repo(`WORKFLOW.md`、`workflows/`) | 規則有版本控制,修改時可以 review | gate 只靠 prompt 約束 |

## 12. 目前的限制

- ledger 的 gate 只靠 prompt 約束,orchestrator 不會驗證。
- 沒有量化資料:沒有系統化記錄耗時、重試次數、token 用量,也無法估算節省了多少工時。
- `.github/` 是空的,repo 沒有設定 CI;Code Review、Rework、Waiting For QA 的流程還沒在真實看板上跑過。
- 一次只能處理一張票。
- Dashboard 沒有登入機制,只適合在本機使用。

可以改進的方向:

- 讓 orchestrator 讀取 ledger,缺少證據時拒收 `handoff.json`。
- 從 stream-json 的 `result` 事件記錄每一輪的耗時與用量,取得實際數據。
- 設定 GitHub Actions。
- 每張票配一台模擬器之後,再評估是否提高併發數。

---

## 13. 面試說明方式

### 30 秒版本

> 我在 TodoList 這個 iOS 專案裡,用 Python 標準函式庫寫了一個本機 orchestrator。RD 貼上 Jira 連結後,它會在這張票專屬的 git worktree 裡啟動無人值守的 Claude Code。agent 寫完規格會停下來,等 RD 在 dashboard 上核准;核准後再實作、編譯、在模擬器截圖驗證,最後把分支交還給 RD。agent 和 orchestrator 之間不用 API,而是用 JSON 檔案溝通。安全方面,我把 Jira 內容當作不可信輸入,在 prompt、工具權限、執行環境三層做限制。

### 建議講述順序(約 5 分鐘)

1. 分工原則:什麼交給 AI,什麼留給人(第 2 節)
2. 架構與一輪流程(第 3、4 節)
3. 挑一個設計決定深入講,建議選「用檔案溝通」(第 6、11 節)
4. 安全(第 8 節)
5. iOS 相關的處理(第 9 節)
6. 主動說明限制與下一步(第 12 節)

### 預期追問

**為什麼不用現成的 agent 框架?**
Claude Code 本身已經提供 agent 迴圈和工具使用。我需要補的只有排程、狀態管理和審核介面,而且需求很具體:本機 Xcode、Jira 整合、人工停止點。自己寫可以掌握每個行為,也不需要額外的套件。

**怎麼確保 agent 不會弄壞 repo?**
說明第 8 節的三層做法,再補上最後一道人工把關:功能票的 PR 由 RD 自己開。同時要誠實說明:這些做法是降低風險,不是保證。

**省了多少時間?**
照實回答:目前沒有量測,所以不給數字。可以說明它把哪些步驟從 RD 手上移走(讀票、寫規格草稿、build、截圖、更新 Jira 進度),以及打算如何量測(從 stream-json 記錄每一輪的耗時與用量)。

**實際跑過多少張票、成功率多少?**
沒有系統化紀錄的話,就照實說沒有統計。不要憑印象給數字。

**agent 卡住或一直做錯怎麼辦?**
- 卡住:15 分鐘沒有輸出就終止 process;沒留下結果時最多自動續跑 2 次;用完就停在 `idle` 等人。
- 做錯:透過審核的 request_changes 或 reject 讓它修正或重做。

**跟 iOS 開發有什麼關係?**
build、測試、模擬器截圖都必須在本機 Xcode 上跑,這決定了架構要放在本機。`ios-build` 讓 agent 能穩定地操作 Xcode,例如用 exit 2 區分「沒有測試」和「測試失敗」。

**如果重新設計會怎麼改?**
把 gate 的驗證從 prompt 移到程式碼裡,並且先把量測機制做起來。

### 回答原則

- 沒有數據就說沒有數據,並說明打算怎麼量測。
- 沒實際跑過的流程(Code Review、Rework)要明講是「已設計、未驗證」。
- 說明設計決定時,好處與代價一起講。

---

## 附錄:關鍵檔案索引

| 內容 | 位置 |
|---|---|
| 讀取狀態、重啟處理 | `pipeline/server.py` `load()` |
| 組 prompt | `pipeline/server.py` `format_history()`、`build_prompt()` |
| 權限參數 | `pipeline/server.py` `permission_list_args()` |
| 模型選擇 | `pipeline/server.py` `select_model()` |
| 派工 | `pipeline/server.py` `dispatch()` |
| 讀取 signal file | `pipeline/server.py` `read_signal()` |
| 收尾與狀態轉換 | `pipeline/server.py` `finish_run()` |
| 排程 | `pipeline/server.py` `scheduler()`、`tick()` |
| 寫入審核結果 | `pipeline/server.py` `submit_review()` |
| HTTP API | `pipeline/server.py` `Handler` |
| 不可信資料規則 | `WORKFLOW.md` |
| Signal file 協定 | `WORKFLOW.md` |
| Shell 指令規則 | `WORKFLOW.md` |
| 狀態對照與路由 | `WORKFLOW.md` |
| Ledger 與 gate | `workflows/_feature.md` |
| 審核留言的安全處理 | `workflows/_feature.md` |
| 設定值 | `pipeline/config.json` |
| 權限白名單與黑名單 | `.claude/settings.json` |
| 流程圖簡報 | `docs/ai-pipeline-slides.html` |
