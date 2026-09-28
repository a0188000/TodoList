//
//  FileTodoStoreTests.swift
//  TodoListTests
//

import Combine
import XCTest
@testable import TodoList

@MainActor
final class FileTodoStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appending(path: "todos.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    // AC-24
    func testMissingFileLoadsEmpty() async throws {
        let store = FileTodoStore(fileURL: fileURL)
        let items = try await store.loadAll()
        XCTAssertTrue(items.isEmpty)
    }

    // AC-11
    func testAddAndCompleteSurviveRelaunch() async throws {
        let store = FileTodoStore(fileURL: fileURL)
        try await store.loadAll()
        try await store.add(title: "買牛奶")
        try await store.add(title: "繳電話費")
        let completedId = try XCTUnwrap(store.items.first { $0.title == "繳電話費" }?.id)
        try await store.markCompleted(id: completedId)

        let relaunched = FileTodoStore(fileURL: fileURL)
        let items = try await relaunched.loadAll()

        XCTAssertEqual(items, store.items)
        XCTAssertEqual(items.first { $0.id == completedId }?.isCompleted, true)
        XCTAssertNotNil(items.first { $0.id == completedId }?.completedAt)
        XCTAssertEqual(items.first { $0.title == "買牛奶" }?.isCompleted, false)
    }

    // AC-13：寫入失敗時資料不變、不發送新增事件
    func testAddFailureLeavesItemsUnchanged() async throws {
        let unwritableURL = directory.appending(path: "missing-dir/todos.json")
        let store = FileTodoStore(fileURL: unwritableURL)
        var addedCount = 0
        let cancellable = store.addedItemPublisher.sink { _ in addedCount += 1 }

        do {
            try await store.add(title: "買牛奶")
            XCTFail("expected save failure")
        } catch {}

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(addedCount, 0)
        cancellable.cancel()
    }

    // SID-2 AC-08 / AC-09：只刪除選取 id（同名保留），重開後不出現
    func testDeleteRemovesOnlyTargetAndSurvivesRelaunch() async throws {
        let store = FileTodoStore(fileURL: fileURL)
        try await store.loadAll()
        try await store.add(title: "買牛奶")
        try await store.add(title: "買牛奶")
        try await store.add(title: "繳電話費")
        let targetId = store.items[0].id
        let keptIds = store.items.dropFirst().map(\.id)

        try await store.delete(id: targetId)

        XCTAssertEqual(store.items.map(\.id), keptIds)
        let relaunched = FileTodoStore(fileURL: fileURL)
        let items = try await relaunched.loadAll()
        XCTAssertEqual(items.map(\.id), keptIds)
        XCTAssertEqual(items.map(\.title), ["買牛奶", "繳電話費"])
    }

    // SID-2 AC-10：寫入失敗時資料不變並拋錯
    func testDeleteFailureLeavesItemsUnchanged() async throws {
        let store = FileTodoStore(fileURL: fileURL)
        try await store.add(title: "買牛奶")
        let before = store.items
        try FileManager.default.removeItem(at: directory)

        do {
            try await store.delete(id: before[0].id)
            XCTFail("expected save failure")
        } catch {}

        XCTAssertEqual(store.items, before)
    }

    // 找不到 id 時不拋錯、資料不變（比照 markCompleted）
    func testDeleteUnknownIdIsNoOp() async throws {
        let store = FileTodoStore(fileURL: fileURL)
        try await store.add(title: "買牛奶")
        let before = store.items

        try await store.delete(id: UUID())

        XCTAssertEqual(store.items, before)
    }

    // OQ-11 預設：毀損資料視為空清單，原檔保留為備份
    func testCorruptFileLoadsEmptyAndKeepsBackup() async throws {
        let corrupt = Data("not json".utf8)
        try corrupt.write(to: fileURL)
        let store = FileTodoStore(fileURL: fileURL)

        let items = try await store.loadAll()

        XCTAssertTrue(items.isEmpty)
        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path())
            .filter { $0.contains("corrupt") }
        XCTAssertEqual(backups.count, 1)
        let backupData = try Data(contentsOf: directory.appending(path: backups[0]))
        XCTAssertEqual(backupData, corrupt)
    }
}
