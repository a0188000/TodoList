//
//  AddTodoViewModelTests.swift
//  TodoListTests
//

import Combine
import XCTest
@testable import TodoList

@MainActor
final class AddTodoViewModelTests: XCTestCase {
    private var store: MockTodoStore!
    private var viewModel: AddTodoViewModel!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()
        store = MockTodoStore()
        viewModel = AddTodoViewModel(store: store)
    }

    // AC-02
    func testInitialStateIsDisabled() {
        XCTAssertFalse(viewModel.isSubmitEnabled)
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertNil(viewModel.errorMessage)
    }

    // AC-03
    func testWhitespaceOnlyTitleKeepsSubmitDisabled() async {
        viewModel.didChangeTitle("   \n ")
        XCTAssertFalse(viewModel.isSubmitEnabled)

        viewModel.didTapSubmit()
        await drainTasks()
        XCTAssertEqual(store.addCallCount, 0)
    }

    // AC-04
    func testValidTitleEnablesSubmit() {
        viewModel.didChangeTitle("買牛奶")
        XCTAssertTrue(viewModel.isSubmitEnabled)
    }

    // AC-17
    func testTitleLengthLimit() {
        viewModel.didChangeTitle(String(repeating: "字", count: 100))
        XCTAssertTrue(viewModel.isSubmitEnabled)

        viewModel.didChangeTitle(String(repeating: "字", count: 101))
        XCTAssertFalse(viewModel.isSubmitEnabled)
    }

    // AC-05 / AC-22
    func testSubmitStoresTrimmedTitleAndFinishes() async {
        var didFinish = false
        viewModel.didFinish.sink { didFinish = true }.store(in: &cancellables)

        viewModel.didChangeTitle("  買牛奶 ")
        viewModel.didTapSubmit()
        await drainTasks()

        XCTAssertEqual(store.items.map(\.title), ["買牛奶"])
        XCTAssertEqual(store.items.first?.isCompleted, false)
        XCTAssertTrue(didFinish)
    }

    // AC-06
    func testRepeatedSubmitCreatesOnlyOneItem() async {
        viewModel.didChangeTitle("買牛奶")
        viewModel.didTapSubmit()
        XCTAssertTrue(viewModel.isSubmitting)
        XCTAssertFalse(viewModel.isSubmitEnabled)
        viewModel.didTapSubmit()
        viewModel.didTapSubmit()
        await drainTasks()

        XCTAssertEqual(store.addCallCount, 1)
        XCTAssertEqual(store.items.count, 1)
    }

    // AC-13
    func testSaveFailureShowsErrorAndAllowsRetry() async {
        var didFinish = false
        viewModel.didFinish.sink { didFinish = true }.store(in: &cancellables)
        store.shouldFail = true

        viewModel.didChangeTitle("買牛奶")
        viewModel.didTapSubmit()
        await drainTasks()

        XCTAssertFalse(didFinish)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "新增失敗，請再試一次")
        XCTAssertFalse(viewModel.isSubmitting)
        XCTAssertTrue(viewModel.isSubmitEnabled)

        store.shouldFail = false
        viewModel.didTapSubmit()
        await drainTasks()
        XCTAssertTrue(didFinish)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(store.items.count, 1)
    }

    // AC-17：允許重複名稱
    func testDuplicateTitlesAreAllowed() async {
        store.items = [makeItem("買牛奶", createdAt: Date())]
        viewModel.didChangeTitle("買牛奶")
        viewModel.didTapSubmit()
        await drainTasks()
        XCTAssertEqual(store.items.count, 2)
    }
}
