//
//  DeleteSwipeActionTests.swift
//  TodoListTests
//

import UIKit
import XCTest
@testable import TodoList

@MainActor
final class DeleteSwipeActionTests: XCTestCase {
    private let baseDate = Date(timeIntervalSince1970: 1_790_000_000)
    /// iOS 26.3 simulator runtime 在 autorelease pool 釋放 VC 時，其 MainActor ViewModel 的 deinit 會於
    /// swift_task_deinitOnExecutor 崩潰（malloc abort），因此讓 VC 存活到測試程序結束。
    private static var retainedViewControllers: [UIViewController] = []

    // SID-2 AC-01 / OQ-05：單一紅色「刪除」、不可 full swipe 直接觸發；左滑本身不刪除
    func testTodoListSwipeShowsSingleDestructiveDelete() async throws {
        let store = MockTodoStore(items: [makeItem("買牛奶", createdAt: baseDate)])
        let viewController = TodoListViewController(viewModel: TodoListViewModel(store: store))
        Self.retainedViewControllers.append(viewController)
        viewController.loadViewIfNeeded()

        let configuration = try XCTUnwrap(viewController.tableView(
            UITableView(), trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)
        ))

        assertSingleDeleteAction(configuration)
        XCTAssertEqual(store.deleteCallCount, 0)
    }

    func testCompletedListSwipeShowsSingleDestructiveDelete() async throws {
        let store = MockTodoStore(items: [makeItem("繳電話費", createdAt: baseDate, completedAt: baseDate)])
        let viewController = CompletedListViewController(viewModel: CompletedListViewModel(store: store))
        Self.retainedViewControllers.append(viewController)
        viewController.loadViewIfNeeded()

        let configuration = try XCTUnwrap(viewController.tableView(
            UITableView(), trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0)
        ))

        assertSingleDeleteAction(configuration)
        XCTAssertEqual(store.deleteCallCount, 0)
    }

    private func assertSingleDeleteAction(_ configuration: UISwipeActionsConfiguration) {
        XCTAssertEqual(configuration.actions.count, 1)
        XCTAssertEqual(configuration.actions.first?.title, "刪除")
        XCTAssertEqual(configuration.actions.first?.style, .destructive)
        XCTAssertFalse(configuration.performsFirstActionWithFullSwipe)
    }
}
