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
    private let countLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private let bannerView = UIView()
    private let bannerLabel = UILabel()
    private weak var deleteConfirmAlert: UIAlertController?

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

        viewModel.$bannerMessage
            .sink { [weak self] message in self?.renderBanner(message) }
            .store(in: &cancellables)

        viewModel.$pendingDelete
            .sink { [weak self] pendingDelete in self?.renderDeleteConfirmation(pendingDelete) }
            .store(in: &cancellables)

        viewModel.errorMessage
            .sink { [weak self] message in self?.showError(message) }
            .store(in: &cancellables)
    }

    private func render(_ state: CompletedListViewModel.State) {
        switch state {
        case .empty:
            rows = []
            countLabel.isHidden = true
            tableView.backgroundView = emptyLabel
        case let .content(rows, countText):
            self.rows = rows
            countLabel.text = countText
            countLabel.isHidden = false
            tableView.backgroundView = nil
        }
        tableView.reloadData()
    }

    private func renderBanner(_ message: String?) {
        if let message {
            bannerLabel.text = message
            UIAccessibility.post(notification: .announcement, argument: message)
        }
        UIView.animate(withDuration: 0.25) {
            self.bannerView.alpha = message == nil ? 0 : 1
        }
    }

    private func renderDeleteConfirmation(_ pendingDelete: PendingDelete?) {
        guard let pendingDelete else {
            // 取消或確認後收合左滑的「刪除」；若確認 dialog 仍在畫面上（非點擊按鈕關閉）則一併收起。
            tableView.setEditing(false, animated: true)
            if let alert = deleteConfirmAlert, alert.presentingViewController != nil, !alert.isBeingDismissed {
                alert.dismiss(animated: false)
            }
            return
        }
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: pendingDelete.title, message: pendingDelete.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { [weak self] _ in self?.viewModel.didCancelDelete() })
        alert.addAction(UIAlertAction(title: "確認", style: .destructive) { [weak self] _ in self?.viewModel.didConfirmDelete() })
        deleteConfirmAlert = alert
        present(alert, animated: true)
    }

    private func showError(_ message: String) {
        if let presented = presentedViewController {
            // 刪除確認 dialog 收合中時，等收合完成再顯示，避免失敗提示被略過（AC-10）。
            if presented.isBeingDismissed, let coordinator = presented.transitionCoordinator {
                coordinator.animate(alongsideTransition: nil) { [weak self] _ in self?.showError(message) }
            }
            return
        }
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好", style: .default))
        present(alert, animated: true)
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

        // 與待辦頁數量文字同樣式（SID-3 PRD §5）。
        countLabel.font = .preferredFont(forTextStyle: .subheadline)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .secondaryLabel
        countLabel.numberOfLines = 0

        let headerStack = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        headerStack.axis = .vertical
        headerStack.spacing = 4

        tableView.backgroundColor = .clear
        tableView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)
        tableView.insetsLayoutMarginsFromSafeArea = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.register(CompletedRowCell.self, forCellReuseIdentifier: CompletedRowCell.reuseIdentifier)

        emptyLabel.text = "尚未有已完成的任務"
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0

        // 與待辦頁「任務已新增」banner 同樣式（OQ-01 / OQ-02）。
        bannerLabel.font = .preferredFont(forTextStyle: .subheadline)
        bannerLabel.adjustsFontForContentSizeCategory = true
        bannerLabel.textColor = .systemBackground
        bannerView.backgroundColor = .label
        bannerView.layer.cornerRadius = 12
        bannerView.alpha = 0
        bannerView.isUserInteractionEnabled = false

        for subview in [headerStack, tableView, bannerView, bannerLabel] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(headerStack)
        view.addSubview(tableView)
        view.addSubview(bannerView)
        bannerView.addSubview(bannerLabel)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            headerStack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),

            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bannerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            bannerView.leadingAnchor.constraint(greaterThanOrEqualTo: view.layoutMarginsGuide.leadingAnchor),
            bannerView.trailingAnchor.constraint(lessThanOrEqualTo: view.layoutMarginsGuide.trailingAnchor),

            bannerLabel.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 10),
            bannerLabel.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -10),
            bannerLabel.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 16),
            bannerLabel.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -16),
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

// MARK: - UITableViewDelegate

extension CompletedListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let id = rows[indexPath.row].id
        let delete = UIContextualAction(style: .destructive, title: "刪除") { [weak self] _, _, completion in
            // 只開確認 dialog；實際刪除在確認之後，因此回報 false 讓列維持原狀。
            self?.viewModel.didTapDelete(id: id)
            completion(false)
        }
        let configuration = UISwipeActionsConfiguration(actions: [delete])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
}
