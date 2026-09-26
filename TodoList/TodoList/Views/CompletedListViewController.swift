//
//  CompletedListViewController.swift
//  TodoList
//

import Combine
import UIKit

final class CompletedListViewController: UIViewController {
    private let viewModel: CompletedListViewModel
    private var rows: [CompletedListViewModel.Row] = []
    private var cancellables = Set<AnyCancellable>()

    private let titleLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()

    init(viewModel: CompletedListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        bindViewModel()
        viewModel.viewDidLoad()
    }

    // MARK: Binding

    private func bindViewModel() {
        viewModel.$state
            .sink { [weak self] state in self?.render(state) }
            .store(in: &cancellables)
    }

    private func render(_ state: CompletedListViewModel.State) {
        switch state {
        case .empty:
            rows = []
            tableView.backgroundView = emptyLabel
        case let .content(rows):
            self.rows = rows
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }

    // MARK: Layout

    private func setUpViews() {
        view.backgroundColor = .systemGroupedBackground
        viewRespectsSystemMinimumLayoutMargins = false
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)

        titleLabel.text = "已完成"
        titleLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 34, weight: .bold))
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header

        tableView.backgroundColor = .clear
        tableView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        tableView.insetsLayoutMarginsFromSafeArea = false
        tableView.dataSource = self
        tableView.allowsSelection = false
        tableView.register(CompletedRowCell.self, forCellReuseIdentifier: CompletedRowCell.reuseIdentifier)

        emptyLabel.text = "尚未有已完成的任務"
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
}

// MARK: - UITableViewDataSource

extension CompletedListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CompletedRowCell.reuseIdentifier, for: indexPath)
        (cell as? CompletedRowCell)?.configure(with: rows[indexPath.row])
        return cell
    }
}
