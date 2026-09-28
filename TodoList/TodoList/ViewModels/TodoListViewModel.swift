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
    @Published private(set) var bannerText = "任務已新增"
    @Published private(set) var pendingDelete: PendingDelete?
    let errorMessage = PassthroughSubject<String, Never>()

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
            .sink { [weak self] item in self?.showBanner(text: "任務已新增", recentlyAddedId: item.id) }
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
                self?.errorMessage.send("標記完成失敗，請再試一次")
            }
            self?.completingIds.remove(id)
        }
    }

    func didTapDelete(id: UUID) {
        guard case let .content(rows, _) = state, let row = rows.first(where: { $0.id == id }) else { return }
        pendingDelete = PendingDelete(id: id, title: row.title, message: "確定要刪除這筆待辦事項嗎？刪除後無法復原。")
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
                self?.showBanner(text: "任務已刪除")
            } catch {
                self?.errorMessage.send("刪除失敗，請再試一次")
            }
        }
    }

    func makeAddTodoViewModel() -> AddTodoViewModel {
        AddTodoViewModel(store: store)
    }

    // MARK: Private

    /// 新回饋取代正在顯示的回饋；非新增回饋會清除「剛剛新增」標示。
    private func showBanner(text: String, recentlyAddedId: UUID? = nil) {
        bannerTask?.cancel()
        bannerText = text
        self.recentlyAddedId = recentlyAddedId
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
