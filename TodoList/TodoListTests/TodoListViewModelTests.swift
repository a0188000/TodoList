//
//  TodoListViewModelTests.swift
//  TodoListTests
//

import Combine
import XCTest
@testable import TodoList

@MainActor
final class TodoListViewModelTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 1_790_000_000)
    private var cancellables = Set<AnyCancellable>()

    // AC-24
    // 建立 ViewModel 的測試皆為 async：iOS 26.3 simulator runtime 在 XCTest 同步方法中釋放
    // MainActor-isolated 物件會於 swift_task_deinitOnExecutor 崩潰（malloc abort）。
    func testEmptyStoreShowsEmptyState() async {
        let viewModel = TodoListViewModel(store: MockTodoStore())
        viewModel.viewDidLoad()
        XCTAssertEqual(viewModel.state, .empty)
    }

    // AC-01 / AC-21
    func testShowsPendingItemsNewestFirstWithCount() async {
        let store = MockTodoStore(items: [
            makeItem("舊", createdAt: baseDate),
            makeItem("新", createdAt: baseDate.addingTimeInterval(60)),
            makeItem("已完成", createdAt: baseDate.addingTimeInterval(120), completedAt: baseDate.addingTimeInterval(180)),
        ])
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        guard case let .content(rows, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.title), ["新", "舊"])
        XCTAssertEqual(countText, "還有 2 件事，從一件開始。")
    }

    // AC-08 / AC-20
    func testAddedItemIsMarkedAndBannerHidesAfterDuration() async throws {
        let store = MockTodoStore(items: [makeItem("舊", createdAt: baseDate)])
        store.now = baseDate.addingTimeInterval(60)
        let viewModel = TodoListViewModel(store: store, bannerDuration: .milliseconds(100))
        viewModel.viewDidLoad()

        try await store.add(title: "新")

        guard case let .content(rows, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.title), ["新", "舊"])
        XCTAssertEqual(rows.map(\.isRecentlyAdded), [true, false])
        XCTAssertEqual(countText, "還有 2 件事，從一件開始。")
        XCTAssertTrue(viewModel.isAddedBannerVisible)

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(viewModel.isAddedBannerVisible)
        guard case let .content(rowsAfter, _) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rowsAfter.map(\.isRecentlyAdded), [false, false])
    }

    // AC-09
    func testTapCircleMovesItemOutOfPending() async {
        let item = makeItem("買牛奶", createdAt: baseDate)
        let store = MockTodoStore(items: [item])
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapCircle(id: item.id)
        await drainTasks()

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertEqual(store.items.first?.isCompleted, true)
        XCTAssertNotNil(store.items.first?.completedAt)
    }

    // AC-09：同一筆連點只寫入一次
    func testRepeatedTapOnSameCircleCompletesOnce() async {
        let item = makeItem("買牛奶", createdAt: baseDate)
        let store = MockTodoStore(items: [item])
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapCircle(id: item.id)
        viewModel.didTapCircle(id: item.id)
        await drainTasks()

        XCTAssertEqual(store.markCompletedCallCount, 1)
    }

    // AC-15
    func testCompletionFailureKeepsItemAndReportsError() async {
        let item = makeItem("買牛奶", createdAt: baseDate)
        let store = MockTodoStore(items: [item])
        store.shouldFail = true
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()
        var messages: [String] = []
        viewModel.errorMessage.sink { messages.append($0) }.store(in: &cancellables)

        viewModel.didTapCircle(id: item.id)
        await drainTasks()

        guard case let .content(rows, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.id), [item.id])
        XCTAssertEqual(countText, "還有 1 件事，從一件開始。")
        XCTAssertEqual(messages, ["標記完成失敗，請再試一次"])

        // 可重試
        store.shouldFail = false
        viewModel.didTapCircle(id: item.id)
        await drainTasks()
        XCTAssertEqual(viewModel.state, .empty)
    }

    // MARK: SID-2 刪除

    private func makeThreeItems() -> [TodoItem] {
        [
            makeItem("買牛奶", createdAt: baseDate.addingTimeInterval(120)),
            makeItem("回覆設計稿", createdAt: baseDate.addingTimeInterval(60)),
            makeItem("整理會議紀錄", createdAt: baseDate),
        ]
    }

    // SID-2 AC-03：點刪除只開 dialog，不刪資料
    func testTapDeleteShowsConfirmationWithoutDeleting() async {
        let items = makeThreeItems()
        let store = MockTodoStore(items: items)
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: items[1].id)
        await drainTasks()

        XCTAssertEqual(viewModel.pendingDelete, PendingDelete(
            id: items[1].id, title: "回覆設計稿", message: "確定要刪除這筆待辦事項嗎？刪除後無法復原。"
        ))
        XCTAssertEqual(store.deleteCallCount, 0)
        XCTAssertEqual(store.items, items)
    }

    // SID-2 AC-04：取消後資料與數量不變
    func testCancelDeleteKeepsEverything() async {
        let items = makeThreeItems()
        let store = MockTodoStore(items: items)
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()
        let stateBefore = viewModel.state

        viewModel.didTapDelete(id: items[0].id)
        viewModel.didCancelDelete()
        await drainTasks()

        XCTAssertNil(viewModel.pendingDelete)
        XCTAssertEqual(viewModel.state, stateBefore)
        XCTAssertEqual(store.deleteCallCount, 0)
        XCTAssertFalse(viewModel.isAddedBannerVisible)
    }

    // SID-2 AC-05 / AC-06：只刪目標、數量 −1、顯示「任務已刪除」後消失
    func testConfirmDeleteRemovesTargetAndShowsBanner() async throws {
        let items = makeThreeItems()
        let store = MockTodoStore(items: items)
        let viewModel = TodoListViewModel(store: store, bannerDuration: .milliseconds(100))
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: items[1].id)
        viewModel.didConfirmDelete()
        XCTAssertNil(viewModel.pendingDelete)
        await drainTasks()

        guard case let .content(rows, countText) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.title), ["買牛奶", "整理會議紀錄"])
        XCTAssertEqual(countText, "還有 2 件事，從一件開始。")
        XCTAssertEqual(viewModel.bannerText, "任務已刪除")
        XCTAssertTrue(viewModel.isAddedBannerVisible)

        try await Task.sleep(for: .milliseconds(300))
        XCTAssertFalse(viewModel.isAddedBannerVisible)
    }

    // SID-2 AC-05：重複確認只送出一次刪除
    func testRepeatedConfirmDeletesOnce() async {
        let items = makeThreeItems()
        let store = MockTodoStore(items: items)
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: items[0].id)
        viewModel.didConfirmDelete()
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(store.deleteCallCount, 1)
    }

    // SID-2 AC-08：同名只刪選取那筆
    func testDeleteSameTitleRemovesOnlySelected() async {
        let first = makeItem("買牛奶", createdAt: baseDate.addingTimeInterval(60))
        let second = makeItem("買牛奶", createdAt: baseDate)
        let store = MockTodoStore(items: [first, second])
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: second.id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(store.items.map(\.id), [first.id])
    }

    // SID-2 SV-08：刪除最後一筆進入空狀態
    func testDeleteLastItemShowsEmptyState() async {
        let item = makeItem("買牛奶", createdAt: baseDate)
        let store = MockTodoStore(items: [item])
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()

        viewModel.didTapDelete(id: item.id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(viewModel.state, .empty)
        XCTAssertEqual(viewModel.bannerText, "任務已刪除")
    }

    // SID-2 OQ-01：刪除回饋取代顯示中的「任務已新增」，並清除「剛剛新增」標示
    func testDeleteBannerReplacesAddedBanner() async throws {
        let items = makeThreeItems()
        let store = MockTodoStore(items: items)
        store.now = baseDate.addingTimeInterval(600)
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()
        try await store.add(title: "新")
        XCTAssertEqual(viewModel.bannerText, "任務已新增")

        viewModel.didTapDelete(id: items[0].id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(viewModel.bannerText, "任務已刪除")
        XCTAssertTrue(viewModel.isAddedBannerVisible)
        guard case let .content(rows, _) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.isRecentlyAdded), [false, false, false])
    }

    // SID-2 AC-10：失敗時資料不變、不顯示成功回饋、送出錯誤、可重試
    func testDeleteFailureKeepsItemAndReportsError() async {
        let items = makeThreeItems()
        let store = MockTodoStore(items: items)
        store.shouldFail = true
        let viewModel = TodoListViewModel(store: store)
        viewModel.viewDidLoad()
        let stateBefore = viewModel.state
        var messages: [String] = []
        viewModel.errorMessage.sink { messages.append($0) }.store(in: &cancellables)

        viewModel.didTapDelete(id: items[0].id)
        viewModel.didConfirmDelete()
        await drainTasks()

        XCTAssertEqual(viewModel.state, stateBefore)
        XCTAssertFalse(viewModel.isAddedBannerVisible)
        XCTAssertEqual(messages, ["刪除失敗，請再試一次"])

        store.shouldFail = false
        viewModel.didTapDelete(id: items[0].id)
        viewModel.didConfirmDelete()
        await drainTasks()
        XCTAssertEqual(store.items.count, 2)
    }
}
