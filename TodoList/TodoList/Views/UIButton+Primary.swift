//
//  UIButton+Primary.swift
//  TodoList
//

import UIKit

extension UIButton {
    /// 主要操作按鈕：藍色、圓角、高度基準 54pt（PRD p5）
    static func makePrimary(title: String) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.baseBackgroundColor = .systemBlue
        configuration.cornerStyle = .large
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .headline)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 54).isActive = true
        return button
    }
}
