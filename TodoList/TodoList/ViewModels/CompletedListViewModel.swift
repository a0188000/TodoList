//
//  CompletedListViewModel.swift
//  TodoList
//

import Combine
import Foundation

final class CompletedListViewModel {
    struct Row: Equatable {
        let id: UUID
        let title: String
        let completedText: String
    }

    enum State: Equatable {
        case empty
        case content(rows: [Row])
    }

    // MARK: Output

    @Published private(set) var state: State = .empty

    // MARK: Private

    private let store: TodoStoring
    private let dateFormatter: CompletionDateFormatter

    init(store: TodoStoring, dateFormatter: CompletionDateFormatter = CompletionDateFormatter()) {
        self.store = store
        self.dateFormatter = dateFormatter
    }

    // MARK: Input

    func viewDidLoad() {
        store.itemsPublisher
            .map { [dateFormatter] items in Self.makeState(items: items, dateFormatter: dateFormatter) }
            .removeDuplicates()
            .assign(to: &$state)
    }

    // MARK: Private

    private static func makeState(items: [TodoItem], dateFormatter: CompletionDateFormatter) -> State {
        let rows = items
            .compactMap { item -> (item: TodoItem, completedAt: Date)? in
                guard item.isCompleted, let completedAt = item.completedAt else { return nil }
                return (item, completedAt)
            }
            .sorted { $0.completedAt > $1.completedAt }
            .map { Row(id: $0.item.id, title: $0.item.title, completedText: dateFormatter.string(from: $0.completedAt)) }
        return rows.isEmpty ? .empty : .content(rows: rows)
    }
}
