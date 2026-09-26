//
//  AddTodoViewModel.swift
//  TodoList
//

import Combine
import Foundation

final class AddTodoViewModel {
    static let maxTitleLength = 100

    // MARK: Output

    @Published private(set) var isSubmitEnabled = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    let didFinish = PassthroughSubject<Void, Never>()

    // MARK: Private

    private let store: TodoStoring
    private var title = ""

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(store: TodoStoring) {
        self.store = store
    }

    // MARK: Input

    func didChangeTitle(_ text: String) {
        title = text
        updateSubmitEnabled()
    }

    func didTapSubmit() {
        guard isSubmitEnabled else { return }
        let title = trimmedTitle
        isSubmitting = true
        errorMessage = nil
        updateSubmitEnabled()
        Task { [weak self, store] in
            do {
                try await store.add(title: title)
                // 成功後維持停用直到畫面關閉，避免關閉動畫期間再次提交。
                self?.didFinish.send()
            } catch {
                self?.isSubmitting = false
                self?.errorMessage = "新增失敗，請再試一次"
                self?.updateSubmitEnabled()
            }
        }
    }

    // MARK: Private

    private func updateSubmitEnabled() {
        let title = trimmedTitle
        isSubmitEnabled = !isSubmitting && !title.isEmpty && title.count <= Self.maxTitleLength
    }
}
