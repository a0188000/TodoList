//
//  TodoListViewModel.swift
//  TodoList
//

import Combine
import Foundation

final class TodoListViewModel {
    struct Row: Equatable {
        let id: UUID
        let title: String
        let isRecentlyAdded: Bool
    }

    enum State: Equatable {
        case empty
        case content(rows: [Row], countText: String)
    }

    // MARK: Output

    @Published private(set) var state: State = .empty
    @Published private(set) var isAddedBannerVisible = false
    let completionErrorMessage = PassthroughSubject<String, Never>()

    // MARK: Private

    private let store: TodoStoring
    private let bannerDuration: Duration
    @Published private var recentlyAddedId: UUID?
    private var completingIds: Set<UUID> = []
    private var bannerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(store: TodoStoring, bannerDuration: Duration = .seconds(3)) {
        self.store = store
        self.bannerDuration = bannerDuration
    }

    // MARK: Input

    func viewDidLoad() {
        store.itemsPublisher
            .combineLatest($recentlyAddedId)
            .map { items, recentlyAddedId in Self.makeState(items: items, recentlyAddedId: recentlyAddedId) }
            .removeDuplicates()
            .assign(to: &$state)

        store.addedItemPublisher
            .sink { [weak self] item in self?.showAddedFeedback(for: item.id) }
            .store(in: &cancellables)

        Task { [store] in
            try? await store.loadAll()
        }
    }

    func didTapCircle(id: UUID) {
        guard !completingIds.contains(id) else { return }
        completingIds.insert(id)
        Task { [weak self, store] in
            do {
                try await store.markCompleted(id: id)
            } catch {
                self?.completionErrorMessage.send("標記完成失敗，請再試一次")
            }
            self?.completingIds.remove(id)
        }
    }

    func makeAddTodoViewModel() -> AddTodoViewModel {
        AddTodoViewModel(store: store)
    }

    // MARK: Private

    private func showAddedFeedback(for id: UUID) {
        bannerTask?.cancel()
        recentlyAddedId = id
        isAddedBannerVisible = true
        bannerTask = Task { [weak self, bannerDuration] in
            try? await Task.sleep(for: bannerDuration)
            guard !Task.isCancelled else { return }
            self?.recentlyAddedId = nil
            self?.isAddedBannerVisible = false
        }
    }

    private static func makeState(items: [TodoItem], recentlyAddedId: UUID?) -> State {
        let rows = items
            .filter { !$0.isCompleted }
            .sorted { $0.createdAt > $1.createdAt }
            .map { Row(id: $0.id, title: $0.title, isRecentlyAdded: $0.id == recentlyAddedId) }
        guard !rows.isEmpty else { return .empty }
        return .content(rows: rows, countText: "還有 \(rows.count) 件事，從一件開始。")
    }
}
