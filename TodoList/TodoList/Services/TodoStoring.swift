//
//  TodoStoring.swift
//  TodoList
//

import Combine
import Foundation

protocol TodoStoring: AnyObject {
    /// 目前全部任務（含已完成）；訂閱時會先收到目前值。
    var itemsPublisher: AnyPublisher<[TodoItem], Never> { get }
    /// 只在 `add(title:)` 成功保存後發送新任務。
    var addedItemPublisher: AnyPublisher<TodoItem, Never> { get }

    @discardableResult
    func loadAll() async throws -> [TodoItem]
    /// 成功保存後才更新 `itemsPublisher`；失敗時資料不變並拋出錯誤。
    func add(title: String) async throws
    /// 成功保存後才更新 `itemsPublisher`；失敗時資料不變並拋出錯誤。
    func markCompleted(id: UUID) async throws
}
