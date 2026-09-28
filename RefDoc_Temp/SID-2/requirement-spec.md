# Todo 刪除功能 - iOS Requirement Spec

> Ticket：SID-2「實作刪除 todo 功能」（feature flow）
> 主要來源：`RefDoc_Temp/SID-2/attachments/Todo_Delete_PRD_v1.1.pdf`（PRD v1.1 正式版，2026-09-28，共 3 頁，已全文閱讀；檔案 git-ignored，不提交）
> Jira 描述：空白；無 comment；無 linked ticket。
> Figma：https://www.figma.com/design/iXusvkslanTTXnoaU8BXm0/TodoList?node-id=10-2 — 本 session 無 Figma MCP 工具，未取得截圖與 design tokens（Visual Spec Asset Gate：N/A — no Figma tool）。
> 前置功能：SID-1（清單 / 新增 / 完成）已實作；既有規則見 `RefDoc_Temp/SID-1/requirement-spec.md`、`RefDoc_Temp/SID-1_handoff.md`。
> Learning log：`.claude/evaluation/agent-learning-log.md` 無任何 entry，本次未套用 lesson。

PRD 用語：「設計已定義」＝來自 Figma 畫面與畫布操作規則；「產品實作要求」＝產品要求；「實作建議」＝PRD 為畫布未呈現的異常狀態所補的建議（本 spec 視為預設實作依據，RTM 信心標 Medium）。

---

## 1. Project Context

### 目標（PRD p1 §1）
- 讓使用者從「待辦」或「已完成」分頁刪除指定 Todo，刪除前二次確認，降低左滑誤觸風險。
- 成功標準：兩個分頁都能完成「左滑 → 刪除 → 二次確認 → 清單更新」；取消不改變資料；確認後只刪除目標 Todo；重新開啟 App 不再出現。

### 範圍（PRD p1 §2）
- 包含：單筆 Todo 左滑露出刪除、確認對話框、取消、確認、列表及數量更新、結果回饋。
- 適用位置：待辦清單與已完成清單的每一筆 Todo cell。
- 資料識別：依 Todo 唯一識別碼（`TodoItem.id: UUID`）定位；title 只用於對話框顯示。

### 不在範圍內（PRD p1 §2）
批次刪除、復原（Undo）、垃圾桶、從對話框編輯任務。既有清單、新增、完成規則沿用 SID-1，不在本次變更範圍。

### App / Backend 職責
本 App 無 backend，資料為本機 JSON（`Documents/todos.json`）。所有需求 source of truth 皆在 App（本機儲存 + client UI state），BE 無工作項目。

---

## 2. Spec ↔ Figma Conflicts

**N/A — no Figma tool available; PRD v1.1 claims to be derived from Figma node 10:2。**

無法比對 PRD 與設計稿；視覺細節（刪除按鈕色值、dialog 樣式、回饋樣式）不做猜測，列入 OQ-07。

PRD 內部需釐清之處（非 Figma 衝突，單一來源資訊不足，已轉 Open Questions）：

| 項目 | PRD 段落 A | PRD 段落 B / 現況 | 處理 |
|------|-----------|-------------------|------|
| 已完成分頁「摘要 / 數量」 | §3.1-05「清單摘要與數量同步更新」、DEL-05「更新所在分頁、摘要或數量」 | §4.1「已完成分頁刪除成功後，只更新其已完成清單」；現有已完成頁無數量 / 摘要 UI | OQ-03 |
| 已完成分頁成功回饋 | §3.1-06、DEL-05：確認後顯示成功回饋（未限分頁） | AC-06 只對待辦要求「任務已刪除」；AC-07 未提回饋 | OQ-02 |
| 取消後 cell 狀態 | §3.1-04「原型返回左滑露出刪除的狀態」 | AC-04 只要求資料不變 | OQ-04 |

---

## 3. 畫面規格

兩個分頁共用同一流程；差異只有 dialog 說明文案與數量更新。

| 步驟 | 待辦分頁 Figma node | 已完成分頁 Figma node |
|------|--------------------|----------------------|
| 01 左滑顯示刪除 | `11:2` | `12:104` |
| 02 刪除二次確認 | `12:2` | `12:157` |
| 03 刪除後清單 | `12:53` | `12:210` |

### 3.1 待辦清單（既有 `TodoListViewController`，改版）
- 顯示：既有標題「待辦事項」、數量文字「還有 N 件事，從一件開始。」、section header「我的清單」、`TodoRowCell`（圓圈 + title + 「剛剛新增」）、「新增任務」按鈕、既有「任務已新增」banner。
- 新互動：
  1. 左滑某列 → 該列右側露出紅色「刪除」；其他列不進入刪除狀態；滑回原位收合（DEL-01）。
  2. 點「刪除」→ 顯示 dialog，資料尚未刪除（DEL-02）。
  3. 「取消」→ 關閉 dialog；資料 / 清單 / 數量不變（DEL-04）；cell 狀態見 OQ-04。
  4. 「確認」→ 依 id 刪除；dialog 關閉；該列消失、其餘上移；數量 −1（Figma 示範 3 → 2）；顯示「任務已刪除」（DEL-05）。刪除最後一筆 → 既有空狀態「目前沒有待辦事項」，數量文字隱藏（SID-1 OQ-10 既有行為）。
  5. 失敗 → 保留原 Todo 與數量，顯示「刪除失敗，請再試一次」，不顯示成功回饋（DEL-07）。
- 導航：無新頁面；dialog 為 modal。

### 3.2 已完成清單（既有 `CompletedListViewController`，改版）
- 顯示：既有標題「已完成」、`CompletedRowCell`（勾選 + 刪除線 title + 完成時間文字）；**無**數量 / 摘要、無 banner、無錯誤提示機制。
- 新互動：同 3.1 步驟 1–5，差異：
  - dialog 說明文案為已完成版本。
  - 成功後只更新已完成清單；待辦清單與待辦數量不受影響（§4.1、AC-07）。
  - 刪除最後一筆 → 既有空狀態「尚未有已完成的任務」。
  - 成功回饋是否顯示見 OQ-02；已完成頁數量 / 摘要見 OQ-03。

### 3.3 文案表

| 位置 | 文案 | 來源 |
|------|------|------|
| 左滑按鈕 | 刪除 | PRD §3.1-01 |
| Dialog 標題 | 目標 Todo 的 title（完全一致） | §3.2、DEL-03、AC-03 |
| Dialog 說明（待辦） | 確定要刪除這筆待辦事項嗎？刪除後無法復原。 | §3.2 |
| Dialog 說明（已完成） | 確定要刪除這筆已完成事項嗎？刪除後無法復原。 | §3.2 |
| Dialog 按鈕 | 取消 ／ 確認（確認為紅色） | §3.1-03 |
| 成功回饋 | 任務已刪除 | §3.1-06、AC-06 |
| 失敗回饋 | 刪除失敗，請再試一次 | §4.1 實作建議 |
| 失敗 alert 關閉按鈕 | 好（沿用 SID-1 完成失敗 alert，PRD 未定義；見 OQ-06） | 既有 code |

### 3.4 視覺變更表

| 元素 | 變更 | 描述 | 來源 |
|------|------|------|------|
| Todo cell（兩分頁） | 新增 | 左滑露出紅色「刪除」按鈕（精確色值未知 → OQ-07） | §3.1-01、11:2 / 12:104 |
| 確認 dialog | 新增 | title + 說明 + 取消 / 紅色確認（系統 alert 或自訂元件未知 → OQ-07） | §3.1-03、12:2 / 12:157 |
| 成功回饋 | 新增 | 「任務已刪除」（形式 / 位置 / 時長 → OQ-01） | §3.1-06、12:53 / 12:210 |
| 失敗回饋 | 新增 | 「刪除失敗，請再試一次」（形式 → OQ-06；N/A (no design)） | §4.1 |
| 其他（背景、佈局、標題、數量樣式） | 不變 | — | — |

---

## 4. State / Variant Matrix

資料載入：本機讀取，無 loading 狀態（沿用 SID-1）。「操作 / 結果 / 資料數量 / 持久化」維度如下。

| ID | 分頁 | 狀態 | 觸發條件 | 來源 | UI 差異 | 實作要求 | AC |
|----|------|------|----------|------|---------|----------|----|
| SV-01 | 待辦 | Normal | 有 ≥1 筆未完成 | SID-1 既有 | baseline | 無變更 | AC-01 前置 |
| SV-02 | 待辦 | 左滑露出刪除 | 對單列左滑 | `11:2`、§3.1-01 | 目標列右側紅色「刪除」 | 僅目標列；資料不變 | AC-01 |
| SV-03 | 待辦 | 收合 | 將已左滑列滑回 | §3.1-01 | 按鈕收合 | 資料不變 | AC-02 |
| SV-04 | 待辦 | 確認 dialog | 點「刪除」 | `12:2`、§3.2 | dialog（title＝todo title、待辦文案） | 資料未變更 | AC-03 |
| SV-05 | 待辦 | 取消 | dialog 點「取消」 | §3.1-04 | dialog 關閉；cell 狀態依 OQ-04 | 資料 / 數量不變 | AC-04 |
| SV-06 | 待辦 | 刪除中 | 點「確認」後、保存完成前 | DEL-08 | N/A (no design)；無可見差異 | 同一筆不重複送出 | AC-05 |
| SV-07 | 待辦 | 成功（N → N−1，N−1 ≥ 1） | 確認且保存成功 | `12:53`、§4.1 | 列消失、其餘上移、數量 −1、「任務已刪除」 | 只刪目標 id | AC-05、AC-06 |
| SV-08 | 待辦 | 成功後為空（1 → 0） | 刪除最後一筆 | 既有空狀態（SID-1） | 「目前沒有待辦事項」、數量隱藏、仍顯示「任務已刪除」；N/A (no design) | 沿用既有 empty | AC-06 |
| SV-09 | 待辦 | 失敗 | 保存失敗 | §4.1、DEL-07 | 「刪除失敗，請再試一次」；N/A (no design) | 資料 / 數量不變、無成功回饋、可重試 | AC-10 |
| SV-10 | 待辦 | 同名 | 兩筆同 title，刪其一 | §4.1 | 另一筆保留 | 以 id 刪除 | AC-08 |
| SV-11 | 待辦 | 回饋重疊 | 「任務已新增」banner 顯示中執行刪除 | 無（PRD 未定義） | N/A (no design) | 見 OQ-01 | AC-06（預設值） |
| SV-12 | 已完成 | Normal | 有 ≥1 筆已完成 | SID-1 既有 | baseline | 無變更 | AC-01 前置 |
| SV-13 | 已完成 | 左滑露出刪除 | 對單列左滑 | `12:104` | 同 SV-02 | 同 SV-02 | AC-01 |
| SV-14 | 已完成 | 收合 | 滑回 | §3.1-01 | 同 SV-03 | 資料不變 | AC-02 |
| SV-15 | 已完成 | 確認 dialog | 點「刪除」 | `12:157`、§3.2 | dialog（已完成文案） | 資料未變更 | AC-03 |
| SV-16 | 已完成 | 取消 | 點「取消」 | §3.1-04 | 同 SV-05 | 資料不變 | AC-04 |
| SV-17 | 已完成 | 刪除中 | 同 SV-06 | DEL-08 | N/A (no design) | 同 SV-06 | AC-05 |
| SV-18 | 已完成 | 成功（N−1 ≥ 1） | 確認且保存成功 | `12:210`、§4.1 | 列消失、其餘上移；回饋依 OQ-02；數量依 OQ-03 | 待辦清單 / 數量不變 | AC-05、AC-07 |
| SV-19 | 已完成 | 成功後為空（1 → 0） | 刪除最後一筆 | 既有空狀態 | 「尚未有已完成的任務」；N/A (no design) | 沿用既有 empty | AC-07 |
| SV-20 | 已完成 | 失敗 | 保存失敗 | §4.1、DEL-07 | 失敗回饋；N/A (no design)；已完成頁目前無錯誤提示機制 | 同 SV-09 | AC-10 |
| SV-21 | 已完成 | 同名 | 同 SV-10 | §4.1 | 另一筆保留 | 以 id 刪除 | AC-08 |
| SV-22 | 全域 | 重啟後 | 刪除成功後重開 App | DEL-06 | 已刪除 Todo 不出現 | 先寫檔成功才更新 UI | AC-09 |

Figma 截圖：N/A — no Figma tool；以上 node id 供 RD 視覺比對。

---

## 5. Requirement Traceability Matrix

| Req ID | 需求 | 來源 | 信心 | 預計實作層 | AC | 驗證方式 |
|--------|------|------|------|------------|----|----------|
| DEL-01 | 兩分頁 cell 左滑露出單筆紅色「刪除」；左滑不刪除；滑回收合 | §3.1-01、DEL-01（設計已定義） | High（色值 Medium → OQ-07；full swipe → OQ-05） | UI（兩個 VC） | AC-01、AC-02 | VC 層 unit test（swipe configuration）+ 手動 / 截圖（OQ-08） |
| DEL-02 | 點刪除先開 dialog，不直接變更資料 | DEL-02 | High | UI + ViewModel | AC-03 | ViewModel unit test（請求刪除後 store 未被呼叫）+ DEBUG hook 截圖 |
| DEL-03 | Dialog title＝目標 title；取消 / 紅色確認；分頁對應說明文案 | §3.1-03、§3.2、DEL-03 | High（dialog 元件樣式 Medium → OQ-07） | ViewModel（文案）+ UI | AC-03 | ViewModel unit test（title / message）+ DEBUG hook 截圖（兩分頁） |
| DEL-04 | 取消後資料 / 清單 / 數量不變 | §3.1-04、DEL-04 | High（cell 狀態 → OQ-04） | UI + ViewModel | AC-04 | ViewModel unit test（取消不呼叫 store、state 不變） |
| DEL-05 | 確認後只刪目標；更新所在分頁與數量；顯示成功回饋 | §3.1-05/06、DEL-05、§4.1 | High（待辦）/ Medium（已完成回饋 OQ-02、摘要 OQ-03；回饋樣式 OQ-01） | Store + ViewModel + UI | AC-05、AC-06、AC-07 | Store / ViewModel unit test + DEBUG hook 截圖 |
| DEL-06 | 刪除結果持久化，重開不出現 | DEL-06（產品實作要求） | High | Store | AC-09 | FileTodoStore round-trip unit test |
| DEL-07 | 失敗時保留資料與數量、顯示「刪除失敗，請再試一次」、不顯示成功回饋 | DEL-07、§4.1（實作建議） | Medium（形式 → OQ-06） | Store + ViewModel + UI | AC-10 | Store / ViewModel unit test + DEBUG 失敗 hook 截圖 |
| DEL-08 | 送出期間暫停重複確認，同一筆不重複刪除 | DEL-08（實作建議） | Medium | ViewModel | AC-05 | ViewModel unit test（重複確認只呼叫 store 一次） |
| DEL-ID | 以唯一 id 刪除，同名只刪選取那筆 | §2 資料識別、§4.1 | High | Store + ViewModel | AC-08 | Store / ViewModel unit test |

---

## 6. Acceptance Scenarios

### AC-01 左滑待辦或已完成項目
- Given 待辦（或已完成）分頁有 ≥2 筆 Todo
- When 對其中一列左滑
- Then 只有該列右側露出紅色「刪除」；資料不變
- 對應：DEL-01；SV-02、SV-13
- 驗證：VC 層 unit test（trailing swipe configuration 只含一個「刪除」destructive action，觸發前 store 未被呼叫）+ 手動左滑截圖（OQ-08）

### AC-02 將已左滑列滑回原位
- Given 某列已露出「刪除」
- When 將該列滑回原位
- Then 刪除按鈕收合；資料不變
- 對應：DEL-01；SV-03、SV-14
- 驗證：手動（系統 swipe 行為；OQ-08）

### AC-03 點擊刪除
- Given 某列已露出「刪除」
- When 點擊「刪除」
- Then 顯示 dialog，標題與該 Todo title 完全一致；說明文案依分頁（§3.3）；按鈕「取消」／紅色「確認」；資料尚未刪除
- 對應：DEL-02、DEL-03；SV-04、SV-15
- 驗證：ViewModel unit test（dialog 內容、store 刪除未被呼叫）+ DEBUG hook 截圖（兩分頁各一，含長 title）

### AC-04 點擊取消
- Given dialog 顯示中
- When 點擊「取消」
- Then dialog 關閉；原項目、清單與數量不變；cell 狀態依 OQ-04
- 對應：DEL-04；SV-05、SV-16
- 驗證：ViewModel unit test（取消後 state 不變、store 刪除呼叫次數 0）

### AC-05 點擊確認
- Given dialog 顯示中，清單有 N 筆
- When 點擊「確認」（含快速重複觸發）
- Then 只刪除目標 Todo；dialog 關閉；其餘項目上移；受影響清單與數量更新；同一筆只送出一次刪除
- 對應：DEL-05、DEL-08；SV-06、SV-07、SV-17、SV-18
- 驗證：ViewModel unit test（rows 移除目標、其餘順序不變；重複確認 store 呼叫 1 次）+ DEBUG hook 截圖

### AC-06 待辦刪除成功
- Given 待辦有 3 筆（Figma 示範）
- When 刪除其中一筆成功
- Then 數量文字變為「還有 2 件事，從一件開始。」；顯示「任務已刪除」（形式依 OQ-01）；刪除最後一筆時顯示空狀態、數量隱藏
- 對應：DEL-05；SV-07、SV-08、SV-11
- 驗證：ViewModel unit test（countText、回饋 output 出現後依時長消失）+ DEBUG hook 截圖（`-UI_SCENARIO content` 的 3 筆待辦）

### AC-07 已完成刪除成功
- Given 已完成有 ≥1 筆、待辦有 N 筆
- When 在已完成分頁刪除一筆成功
- Then 目標從已完成清單消失；待辦清單與數量不變；成功回饋依 OQ-02；刪除最後一筆顯示「尚未有已完成的任務」
- 對應：DEL-05；SV-18、SV-19
- 驗證：ViewModel unit test（CompletedListViewModel rows 更新 + 同 store 的 TodoListViewModel state 不變）+ DEBUG hook 截圖（`-UI_TAB completed`）

### AC-08 同名 Todo 中刪除其中一筆
- Given 同一分頁有兩筆 title 相同的 Todo
- When 刪除其中一筆
- Then 只有選取那筆（依 id）被刪除，另一筆保留
- 對應：DEL-ID；SV-10、SV-21
- 驗證：Store unit test + ViewModel unit test

### AC-09 重新開啟 App
- Given 已成功刪除某 Todo
- When 關閉並重新開啟 App
- Then 已刪除 Todo 不出現；其他 Todo 完整保留
- 對應：DEL-06；SV-22
- 驗證：FileTodoStore unit test（刪除後新 instance `loadAll()` 不含該 id）；實機重開為手動補充

### AC-10 刪除或保存失敗
- Given 保存會失敗
- When 確認刪除
- Then 資料與數量不變；顯示「刪除失敗，請再試一次」；不顯示「任務已刪除」；可再次刪除重試
- 對應：DEL-07；SV-09、SV-20
- 驗證：FileTodoStore unit test（寫入失敗時 items 不變並拋錯）+ ViewModel unit test（MockTodoStore `shouldFail`）+ DEBUG 失敗 hook 截圖（兩分頁）

### SV → AC 對照檢查
SV-01~22 皆有對應 AC。SV-06 / SV-17（刪除中）無可見差異，以 unit test 驗證；SV-11 行為待 OQ-01 預設值。

---

## 7. Open Questions

### Source A — PRD 自行標記的不確定
掃描 PRD v1.1 全 3 頁（§1、§2、§3、§3.1、§3.2、§4、§4.1、§5）關鍵字 `待確認` / `待補充` / `待評估` / `請…確認` / `TBD` / `TODO`：**無命中**。PRD 以「實作建議」標示 DEL-07、DEL-08 與 §4.1 失敗文案，本 spec 採為預設（信心 Medium），不另列 OQ。Jira 描述空白、無 comment；learning log 無 entry。

### Source B — 分析後仍未決

| ID | 問題 | 影響 | 建議預設值 | Owner | Blocking phase |
|----|------|------|-----------|-------|----------------|
| OQ-01 | 「任務已刪除」回饋形式、位置、時長；與顯示中的「任務已新增」banner 如何共存 | AC-06、SV-11 | 沿用待辦頁既有 banner 樣式（深色圓角、約 3 秒、VoiceOver announcement），文字改為「任務已刪除」；新回饋取代正在顯示的回饋 | PM / Design | UI 實作前；不阻擋 Store / ViewModel |
| OQ-02 | 已完成分頁刪除成功是否也顯示「任務已刪除」（DEL-05 未限分頁，AC-06/07 只對待辦要求） | AC-07、SV-18 | 顯示（依 DEL-05 / §3.1-06），樣式同 OQ-01；已完成頁需新增回饋元件 | PM | 已完成 UI 實作前 |
| OQ-03 | 已完成分頁是否需要「摘要 / 數量」（§3.1-05 提到摘要，§4.1 說只更新已完成清單；現有頁無此 UI） | AC-07 | 不新增數量 / 摘要，只更新清單；請 Design 以 Figma `12:104` / `12:210` 確認 | PM / Design | 不阻擋（採預設）；Spec Review 確認 |
| OQ-04 | 點「取消」後 cell 保持露出「刪除」或收合（PRD 註明原型返回露出狀態，AC-04 未要求） | AC-04 | 依原型保持露出「刪除」；若 UIKit 行為限制，收合亦可接受（資料不變為驗收重點） | Design / RD | UI 實作前 |
| OQ-05 | 完整左滑（full swipe）是否直接觸發「刪除」→ 開 dialog | AC-01、DEL-01 | 關閉 full swipe，只露出按鈕，需點擊才開 dialog（符合「露出 → 點擊」流程、降低誤觸） | Design / RD | UI 實作前 |
| OQ-06 | 刪除失敗回饋形式（alert / banner）與按鈕文案 | AC-10 | 比照 SID-1 完成失敗：系統 alert，title「刪除失敗，請再試一次」，按鈕「好」；兩分頁一致 | PM | 不阻擋（採預設） |
| OQ-07 | Figma 無法讀取：刪除按鈕色值、dialog 元件（系統 alert 或自訂）、回饋樣式、刪除動畫皆未知 | 視覺還原、截圖驗收 | 系統 destructive swipe action（系統紅）+ 系統 alert（取消 cancel style、確認 destructive style）；列移除動畫不強制 | RD（提供截圖或 token）/ Design | Validation Gate 視覺驗收；不阻擋功能 |
| OQ-08 | 左滑狀態（AC-01 / AC-02）截圖證據：專案無 UI test target，`simctl` 無法模擬滑動，swipe 狀態無法由 DEBUG hook 直接呈現 | AC-01、AC-02 驗證證據 | swipe configuration 以 VC 層 unit test 驗證；左滑 / 收合截圖由 RD 手動補充，於 handoff 標示 | RD | Validation Gate |

### 掃描紀錄
- PRD：全文 3 頁，關鍵字見 Source A。
- Figma：無工具（N/A）。
- 附件：僅 PRD 一份。
- Codebase：`TodoItem`、`TodoStoring`、`FileTodoStore`、兩個 ListViewModel / ViewController / Cell、`DebugLaunchScenario`、`MockTodoStore` 與既有 tests（見 `codebase-analysis.md`）；確認已完成頁無數量 / 回饋 / 錯誤 UI（→ OQ-02、OQ-03）。
- Learning log：無 entry。

---

## 8. Design Reference

| 畫面 | 待辦 node | 已完成 node |
|------|-----------|-------------|
| 左滑顯示刪除 | `11:2` | `12:104` |
| 刪除二次確認 | `12:2` | `12:157` |
| 刪除後清單 | `12:53` | `12:210` |
| 畫布 | `10:2` | — |

Design tokens：N/A — no Figma tool。已知文字規格：刪除按鈕紅色（§3.1-01）、確認按鈕紅色（§3.1-03）。其餘沿用 SID-1 視覺基準（系統語意色、左右 24pt、insetGrouped 清單）。
