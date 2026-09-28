//
//  PendingDelete.swift
//  TodoList
//

import Foundation

/// 等待使用者確認的刪除（確認 dialog 的內容）。
struct PendingDelete: Equatable {
    let id: UUID
    let title: String
    let message: String
}
