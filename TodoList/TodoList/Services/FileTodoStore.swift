//
//  FileTodoStore.swift
//  TodoList
//

import Combine
import Foundation

final class FileTodoStore: TodoStoring {
    static let defaultFileURL = URL.documentsDirectory.appending(path: "todos.json")

    @Published private(set) var items: [TodoItem] = []
    private let addedItemSubject = PassthroughSubject<TodoItem, Never>()
    private let fileURL: URL
    private let now: () -> Date

    init(fileURL: URL = FileTodoStore.defaultFileURL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
    }

    var itemsPublisher: AnyPublisher<[TodoItem], Never> {
        $items.eraseToAnyPublisher()
    }

    var addedItemPublisher: AnyPublisher<TodoItem, Never> {
        addedItemSubject.eraseToAnyPublisher()
    }

    @discardableResult
    func loadAll() async throws -> [TodoItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            items = []
            return items
        }
        let data = try Data(contentsOf: fileURL)
        do {
            items = try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            // OQ-11 預設：資料毀損視為空清單；原檔改名保留，避免之後的寫入覆蓋造成資料遺失。
            let backupURL = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(now().timeIntervalSince1970)).json")
            try FileManager.default.moveItem(at: fileURL, to: backupURL)
            items = []
        }
        return items
    }

    func add(title: String) async throws {
        let item = TodoItem(id: UUID(), title: title, isCompleted: false, createdAt: now(), completedAt: nil)
        let newItems = items + [item]
        try save(newItems)
        items = newItems
        addedItemSubject.send(item)
    }

    func markCompleted(id: UUID) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isCompleted else { return }
        var newItems = items
        newItems[index].isCompleted = true
        newItems[index].completedAt = now()
        try save(newItems)
        items = newItems
    }

    private func save(_ items: [TodoItem]) throws {
        let data = try JSONEncoder().encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
