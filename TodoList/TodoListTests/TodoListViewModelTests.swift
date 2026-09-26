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
        viewModel.completionErrorMessage.sink { messages.append($0) }.store(in: &cancellables)

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
}
