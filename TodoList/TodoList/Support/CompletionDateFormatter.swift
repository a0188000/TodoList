//
//  CompletionDateFormatter.swift
//  TodoList
//

import Foundation

/// completedAt → 「今天完成」/「昨天完成」/「M月d日完成」（跨年加年份，OQ-09 預設）
struct CompletionDateFormatter {
    var now: () -> Date = Date.init
    var calendar: Calendar = .current

    func string(from date: Date) -> String {
        let today = now()
        if calendar.isDate(date, inSameDayAs: today) {
            return "今天完成"
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return "昨天完成"
        }
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)
        if year == calendar.component(.year, from: today) {
            return "\(month)月\(day)日完成"
        }
        return "\(year)年\(month)月\(day)日完成"
    }
}
