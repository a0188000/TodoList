//
//  DebugLaunchScenario.swift
//  TodoList
//

#if DEBUG
import Combine
import Foundation
import UIKit

/// 驗證截圖用的 DEBUG hook（不進 Release）。透過 launch argument 啟動：
/// `-UI_SCENARIO <empty|content|many>`、`-UI_TAB completed`、`-UI_ADD <open|success>`、
/// `-UI_DELETE <open|success|failure>`（對目前分頁第一筆執行刪除流程）
struct DebugLaunchScenario {
    let data: String
    let tab: String?
    let add: String?
    let delete: String?

    static var current: DebugLaunchScenario? {
        let defaults = UserDefaults.standard
        guard let data = defaults.string(forKey: "UI_SCENARIO") else { return nil }
        return DebugLaunchScenario(
            data: data,
            tab: defaults.string(forKey: "UI_TAB"),
            add: defaults.string(forKey: "UI_ADD"),
            delete: defaults.string(forKey: "UI_DELETE")
        )
    }

    func makeStore() -> TodoStoring {
        let fileURL = FileManager.default.temporaryDirectory.appending(path: "ui-scenario.json")
        try? FileManager.default.removeItem(at: fileURL)
        let items = seedItems()
        if !items.isEmpty, let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL)
        }
        let store = FileTodoStore(fileURL: fileURL)
        return delete == "failure" ? FailingDeleteTodoStore(base: store) : store
    }

    func apply(
        tabBarController: UITabBarController,
        todoListViewController: TodoListViewController,
        todoListViewModel: TodoListViewModel,
        completedListViewModel: CompletedListViewModel,
        store: TodoStoring
    ) {
        if tab == "completed" {
            tabBarController.selectedIndex = 1
        }
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            switch add {
            case "open":
                todoListViewController.presentAddTodo()
            case "success":
                try? await store.add(title: "閱讀 20 分鐘")
            default:
                break
            }
            guard let delete else { return }
            if tab == "completed" {
                guard case let .content(rows) = completedListViewModel.state, let row = rows.first else { return }
                completedListViewModel.didTapDelete(id: row.id)
                if delete != "open" {
                    try? await Task.sleep(for: .milliseconds(800))
                    completedListViewModel.didConfirmDelete()
                }
            } else {
                guard case let .content(rows, _) = todoListViewModel.state, let row = rows.first else { return }
                todoListViewModel.didTapDelete(id: row.id)
                if delete != "open" {
                    try? await Task.sleep(for: .milliseconds(800))
                    todoListViewModel.didConfirmDelete()
                }
            }
        }
    }

    private func seedItems() -> [TodoItem] {
        let now = Date()
        func pending(_ title: String, minutesAgo: Double) -> TodoItem {
            TodoItem(id: UUID(), title: title, isCompleted: false, createdAt: now.addingTimeInterval(-minutesAgo * 60), completedAt: nil)
        }
        func completed(_ title: String, daysAgo: Double) -> TodoItem {
            TodoItem(
                id: UUID(), title: title, isCompleted: true,
                createdAt: now.addingTimeInterval(-(daysAgo + 1) * 86400),
                completedAt: now.addingTimeInterval(-daysAgo * 86400)
            )
        }
        switch data {
        case "content":
            return [
                pending("買牛奶", minutesAgo: 30),
                pending("回覆設計稿意見，確認空狀態、鍵盤與錯誤提示的設計補齊時程，並同步給開發團隊", minutesAgo: 20),
                pending("整理本週會議紀錄", minutesAgo: 10),
                completed("繳電話費", daysAgo: 0),
                completed("預約牙醫", daysAgo: 1),
                completed("寄出包裹", daysAgo: 5),
            ]
        case "many":
            return (1 ... 15).map { index in
                pending(index == 15 ? "第 \(index) 件事：這是一個很長的任務名稱，用來確認名稱會換行完整顯示而不會被截斷" : "第 \(index) 件事", minutesAgo: Double(15 - index))
            }
        default:
            return []
        }
    }
}

/// `-UI_DELETE failure` 用：刪除一律失敗，其餘轉給真正的 store。
private final class FailingDeleteTodoStore: TodoStoring {
    struct DeleteError: Error {}

    private let base: FileTodoStore

    init(base: FileTodoStore) {
        self.base = base
    }

    var itemsPublisher: AnyPublisher<[TodoItem], Never> { base.itemsPublisher }
    var addedItemPublisher: AnyPublisher<TodoItem, Never> { base.addedItemPublisher }

    func loadAll() async throws -> [TodoItem] { try await base.loadAll() }
    func add(title: String) async throws { try await base.add(title: title) }
    func markCompleted(id: UUID) async throws { try await base.markCompleted(id: id) }
    func delete(id: UUID) async throws { throw DeleteError() }
}
#endif
