//
//  TodoRowCell.swift
//  TodoList
//

import UIKit

final class TodoRowCell: UITableViewCell {
    static let reuseIdentifier = "TodoRowCell"

    var onTapCircle: (() -> Void)?

    private let circleButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let recentlyAddedLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onTapCircle = nil
    }

    func configure(with row: TodoListViewModel.Row) {
        titleLabel.text = row.title
        recentlyAddedLabel.isHidden = !row.isRecentlyAdded
        circleButton.accessibilityLabel = "將「\(row.title)」標記為完成"
        circleButton.accessibilityValue = "未完成"
    }

    private func setUpViews() {
        selectionStyle = .none

        // 圓圈視覺 24pt，觸控範圍 44 × 44pt（PRD p5）
        circleButton.setImage(
            UIImage(systemName: "circle", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22)),
            for: .normal
        )
        circleButton.tintColor = .tertiaryLabel
        circleButton.addAction(UIAction { [weak self] _ in self?.onTapCircle?() }, for: .touchUpInside)

        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.textColor = .label

        recentlyAddedLabel.text = "剛剛新增"
        recentlyAddedLabel.font = .preferredFont(forTextStyle: .caption1)
        recentlyAddedLabel.adjustsFontForContentSizeCategory = true
        recentlyAddedLabel.textColor = .tintColor
        recentlyAddedLabel.isHidden = true

        let textStack = UIStackView(arrangedSubviews: [titleLabel, recentlyAddedLabel])
        textStack.axis = .vertical
        textStack.spacing = 2

        circleButton.translatesAutoresizingMaskIntoConstraints = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(circleButton)
        contentView.addSubview(textStack)

        NSLayoutConstraint.activate([
            circleButton.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor, constant: -10),
            circleButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            circleButton.widthAnchor.constraint(equalToConstant: 44),
            circleButton.heightAnchor.constraint(equalToConstant: 44),
            circleButton.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor),
            circleButton.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor),

            textStack.leadingAnchor.constraint(equalTo: circleButton.trailingAnchor, constant: 4),
            textStack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }
}
