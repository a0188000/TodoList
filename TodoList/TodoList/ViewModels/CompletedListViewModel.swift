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
        case content(rows: [Row], countText: String)
    }

    // MARK: Output

    @Published private(set) var state: State = .empty
    /// nil 時隱藏 banner。
    @Published private(set) var bannerMessage: String?
    @Published private(set) var pendingDelete: PendingDelete?
    let errorMessage = PassthroughSubject<String, Never>()

    // MARK: Private

    private let store: TodoStoring
    private let dateFormatter: CompletionDateFormatter
    private let bannerDuration: Duration
    private var bannerTask: Task<Void, Never>?

    init(
        store: TodoStoring,
        dateFormatter: CompletionDateFormatter = CompletionDateFormatter(),
        bannerDuration: Duration = .seconds(3)
    ) {
        self.store = store
        self.dateFormatter = dateFormatter
        self.bannerDuration = bannerDuration
    }

    // MARK: Input

    func viewDidLoad() {
        store.itemsPublisher
            .map { [dateFormatter] items in Self.makeState(items: items, dateFormatter: dateFormatter) }
            .removeDuplicates()
            .assign(to: &$state)
    }

    func didTapDelete(id: UUID) {
        guard case let .content(rows, _) = state, let row = rows.first(where: { $0.id == id }) else { return }
        pendingDelete = PendingDelete(id: id, title: row.title, message: "確定要刪除這筆已完成事項嗎？刪除後無法復原。")
    }

    func didCancelDelete() {
        pendingDelete = nil
    }

    func didConfirmDelete() {
        // 同步清空，重複確認時直接略過（同一筆只送出一次）。
        guard let pending = pendingDelete else { return }
        pendingDelete = nil
        Task { [weak self, store] in
            do {
                try await store.delete(id: pending.id)
                self?.showBanner("任務已刪除")
            } catch {
                self?.errorMessage.send("刪除失敗，請再試一次")
            }
        }
    }

    // MARK: Private

    private func showBanner(_ message: String) {
        bannerTask?.cancel()
        bannerMessage = message
        bannerTask = Task { [weak self, bannerDuration] in
            try? await Task.sleep(for: bannerDuration)
            guard !Task.isCancelled else { return }
            self?.bannerMessage = nil
        }
    }

    private static func makeState(items: [TodoItem], dateFormatter: CompletionDateFormatter) -> State {
        let rows = items
            .compactMap { item -> (item: TodoItem, completedAt: Date)? in
                guard item.isCompleted, let completedAt = item.completedAt else { return nil }
                return (item, completedAt)
            }
            .sorted { $0.completedAt > $1.completedAt }
            .map { Row(id: $0.item.id, title: $0.item.title, completedText: dateFormatter.string(from: $0.completedAt)) }
        return rows.isEmpty ? .empty : .content(rows: rows, countText: "共完成 \(rows.count) 件")
    }
}
