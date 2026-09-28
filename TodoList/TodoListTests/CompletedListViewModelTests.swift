//
//  CompletedListViewModelTests.swift
//  TodoListTests
//

import Combine
import XCTest
@testable import TodoList

@MainActor
final class CompletedListViewModelTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Taipei")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    // AC-19 / SID-3 AC-3：沒有已完成時為空狀態（不帶數量文字）
    // 建立 ViewModel 的測試皆為 async：iOS 26.3 simulator runtime 在 XCTest 同步方法中釋放
    // MainActor-isolated 物件會於 swift_task_deinitOnExecutor 崩潰（malloc abort）。
    func testNoCompletedItemsShowsEmptyState() async {
        let store = MockTodoStore(items: [makeItem("未完成", createdAt: date(2026, 9, 26))])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()
        XCTAssertEqual(viewModel.state, .empty)
    }

    // AC-18 / AC-21
    func testCompletedItemsSortedNewestFirstWithRelativeText() async {
        let now = date(2026, 9, 26, 15)
        let store = MockTodoStore(items: [
            makeItem("更早", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 20)),
            makeItem("今天", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26, 1)),
            makeItem("昨天", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 25, 23)),
            makeItem("未完成", createdAt: date(2026, 9, 26)),
        ])
        let formatter = CompletionDateFormatter(now: { now }, calendar: calendar)
        let viewModel = CompletedListViewModel(store: store, dateFormatter: formatter)
        viewModel.viewDidLoad()

        guard case let .content(rows, _) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.title), ["今天", "昨天", "更早"])
        XCTAssertEqual(rows.map(\.completedText), ["今天完成", "昨天完成", "9月20日完成"])
    }

    // AC-09：完成後即時出現在已完成清單
    func testNewlyCompletedItemAppears() async throws {
        let item = makeItem("買牛奶", createdAt: date(2026, 9, 26))
        let store = MockTodoStore(items: [item])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()
        XCTAssertEqual(viewModel.state, .empty)

        try await store.markCompleted(id: item.id)

        guard case let .content(rows, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.id), [item.id])
        XCTAssertEqual(countText, "共完成 1 件")
    }

    // MARK: SID-3 完成數量

    // SID-3 AC-1
    func testSingleCompletedItemShowsCountText() async {
        let store = MockTodoStore(items: [
            makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26)),
        ])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()

        guard case let .content(_, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(countText, "共完成 1 件")
    }

    // SID-3 AC-2：未完成不計入
    func testCountTextExcludesPendingItems() async {
        let store = MockTodoStore(items: [
            makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26)),
            makeItem("預約牙醫", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 25)),
            makeItem("寄出包裹", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 24)),
            makeItem("買牛奶", createdAt: date(2026, 9, 26)),
            makeItem("整理桌面", createdAt: date(2026, 9, 26)),
        ])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()

        guard case let .content(_, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(countText, "共完成 3 件")
    }

    // SID-3 AC-4：刪除後數量即時更新
    func testDeleteUpdatesCountText() async {
        let first = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26))
        let second = makeItem("預約牙醫", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 25))
        let store = MockTodoStore(items: [first, second])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()
        guard case let .content(_, countBefore) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(countBefore, "共完成 2 件")

        viewModel.didTapDelete(id: first.id)
        viewModel.didConfirmDelete()
        await drainTasks()

        guard case let .content(_, countAfter) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(countAfter, "共完成 1 件")
    }

    // MARK: SID-2 刪除

    // SID-2 AC-03 / AC-04：點刪除只開 dialog（已完成文案），取消不變
    func testTapDeleteShowsConfirmationAndCancelKeepsItems() async {
        let item = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26))
        let store = MockTodoStore(items: [item])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()
        let stateBefore = viewModel.state

        viewModel.didTapDelete(id: item.id)
        XCTAssertEqual(viewModel.pendingDelete, PendingDelete(
            id: item.id, title: "繳電話費", message: "確定要刪除這筆已完成事項嗎？刪除後無法復原。"
        ))

        viewModel.didCancelDelete()
        await drainTasks()

        XCTAssertNil(viewModel.pendingDelete)
        XCTAssertEqual(viewModel.state, stateBefore)
        XCTAssertEqual(store.deleteCallCount, 0)
    }

    // SID-2 AC-05 / AC-07：只刪目標、顯示「任務已刪除」、待辦不受影響、重複確認只送一次
    func testConfirmDeleteRemovesTargetWithoutAffectingPending() async throws {
        let pending = makeItem("買牛奶", createdAt: date(2026, 9, 26))
        let first = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26))
        let second = makeItem("預約牙醫", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 25))
        let store = MockTodoStore(items: [pending, first, second])
        let todoListViewModel = TodoListViewModel(store: store)
        todoListViewModel.viewDidLoad()
        let todoStateBefore = todoListViewModel.state
        let viewModel = CompletedListViewModel(store: store, bannerDuration: .milliseconds(100))
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: first.id)
        viewModel.didConfirmDelete()
        viewModel.didConfirmDelete()
        await drainTasks()

        guard case let .content(rows, _) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.id), [second.id])
        XCTAssertEqual(store.deleteCallCount, 1)
        XCTAssertEqual(viewModel.bannerMessage, "任務已刪除")
        XCTAssertEqual(todoListViewModel.state, todoStateBefore)

        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(viewModel.bannerMessage)
    }

    // SID-2 AC-08 / SV-21：同名只刪選取那筆
    func testDeleteSameTitleRemovesOnlySelected() async {
        let first = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26))
        let second = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 25))
        let store = MockTodoStore(items: [first, second])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: second.id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(store.items.map(\.id), [first.id])
    }

    // SID-2 SV-19 / SID-3 AC-5：刪除最後一筆進入空狀態，數量文字隱藏
    func testDeleteLastItemShowsEmptyState() async {
        let item = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26))
        let store = MockTodoStore(items: [item])
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()
        guard case let .content(_, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(countText, "共完成 1 件")

        viewModel.didTapDelete(id: item.id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(viewModel.state, .empty)
    }

    // SID-2 AC-10：失敗時資料不變、不顯示成功回饋、送出錯誤
    func testDeleteFailureKeepsItemAndReportsError() async {
        let item = makeItem("繳電話費", createdAt: date(2026, 9, 1), completedAt: date(2026, 9, 26))
        let store = MockTodoStore(items: [item])
        store.shouldFail = true
        let viewModel = CompletedListViewModel(store: store)
        viewModel.viewDidLoad()
        let stateBefore = viewModel.state
        var messages: [String] = []
        let cancellable = viewModel.errorMessage.sink { messages.append($0) }

        viewModel.didTapDelete(id: item.id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(viewModel.state, stateBefore)
        XCTAssertNil(viewModel.bannerMessage)
        XCTAssertEqual(messages, ["刪除失敗，請再試一次"])
        cancellable.cancel()
    }

    // OQ-09 預設：跨年顯示年份
    func testFormatterShowsYearForPreviousYear() {
        let formatter = CompletionDateFormatter(now: { self.date(2026, 1, 5) }, calendar: calendar)
        XCTAssertEqual(formatter.string(from: date(2025, 12, 20)), "2025年12月20日完成")
    }
}
