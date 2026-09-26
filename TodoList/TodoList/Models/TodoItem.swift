//
//  TodoItem.swift
//  TodoList
//

import Foundation

struct TodoItem: Codable, Equatable, Identifiable {
    let id: UUID
    let title: String
    var isCompleted: Bool
    let createdAt: Date
    var completedAt: Date?
}
