//
//  MockTodoStore.swift
//  TodoListTests
//

import Combine
import Foundation
@testable import TodoList

@MainActor
final class MockTodoStore: TodoStoring {
    struct SaveError: Error {}

    @Published var items: [TodoItem]
    var shouldFail = false
    private(set) var addCallCount = 0
    private(set) var markCompletedCallCount = 0
    private let addedItemSubject = PassthroughSubject<TodoItem, Never>()
    var now = Date()

    init(items: [TodoItem] = []) {
        self.items = items
    }

    var itemsPublisher: AnyPublisher<[TodoItem], Never> { $items.eraseToAnyPublisher() }
    var addedItemPublisher: AnyPublisher<TodoItem, Never> { addedItemSubject.eraseToAnyPublisher() }

    func loadAll() async throws -> [TodoItem] { items }

    func add(title: String) async throws {
        addCallCount += 1
        await Task.yield()
        if shouldFail { throw SaveError() }
        let item = TodoItem(id: UUID(), title: title, isCompleted: false, createdAt: now, completedAt: nil)
        items.append(item)
        addedItemSubject.send(item)
    }

    func markCompleted(id: UUID) async throws {
        markCompletedCallCount += 1
        await Task.yield()
        if shouldFail { throw SaveError() }
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted = true
        items[index].completedAt = now
    }
}

@MainActor
func makeItem(_ title: String, createdAt: Date, completedAt: Date? = nil) -> TodoItem {
    TodoItem(id: UUID(), title: title, isCompleted: completedAt != nil, createdAt: createdAt, completedAt: completedAt)
}

/// 讓已排入的 MainActor Task 執行完畢。
@MainActor
func drainTasks() async {
    for _ in 0 ..< 10 {
        await Task.yield()
    }
}
