//
//  CompletedRowCell.swift
//  TodoList
//

import UIKit

final class CompletedRowCell: UITableViewCell {
    static let reuseIdentifier = "CompletedRowCell"

    private let checkmarkView = UIImageView()
    private let titleLabel = UILabel()
    private let completedLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with row: CompletedListViewModel.Row) {
        titleLabel.attributedText = NSAttributedString(
            string: row.title,
            attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        )
        completedLabel.text = row.completedText
        accessibilityLabel = "\(row.title)，已完成，\(row.completedText)"
    }

    private func setUpViews() {
        selectionStyle = .none
        isAccessibilityElement = true

        checkmarkView.image = UIImage(
            systemName: "checkmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)
        )
        checkmarkView.tintColor = .systemBlue
        checkmarkView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .secondaryLabel

        completedLabel.font = .preferredFont(forTextStyle: .caption1)
        completedLabel.adjustsFontForContentSizeCategory = true
        completedLabel.textColor = .secondaryLabel

        let textStack = UIStackView(arrangedSubviews: [titleLabel, completedLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        let rowStack = UIStackView(arrangedSubviews: [checkmarkView, textStack])
        rowStack.spacing = 12
        rowStack.alignment = .center
        rowStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rowStack)

        NSLayoutConstraint.activate([
            rowStack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            rowStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            rowStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            rowStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }
}
