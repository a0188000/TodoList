//
//  CompletedListViewModelTests.swift
//  TodoListTests
//

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

    // AC-19
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

        guard case let .content(rows) = viewModel.state else {
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

        guard case let .content(rows) = viewModel.state else {
            return XCTFail("expected content state")
        }
        XCTAssertEqual(rows.map(\.id), [item.id])
    }

    // OQ-09 預設：跨年顯示年份
    func testFormatterShowsYearForPreviousYear() {
        let formatter = CompletionDateFormatter(now: { self.date(2026, 1, 5) }, calendar: calendar)
        XCTAssertEqual(formatter.string(from: date(2025, 12, 20)), "2025年12月20日完成")
    }
}
