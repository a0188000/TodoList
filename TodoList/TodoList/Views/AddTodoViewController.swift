//
//  AddTodoViewController.swift
//  TodoList
//

import Combine
import UIKit

final class AddTodoViewController: UIViewController {
    private let viewModel: AddTodoViewModel
    private var cancellables = Set<AnyCancellable>()

    private let cancelButton = UIButton(configuration: .plain())
    private let addButton = UIButton(configuration: .plain())
    private let titleLabel = UILabel()
    private let fieldLabel = UILabel()
    private let fieldContainer = UIView()
    private let textField = UITextField()
    private let helperLabel = UILabel()
    private let errorLabel = UILabel()
    private let submitButton = UIButton.makePrimary(title: "新增到清單")

    init(viewModel: AddTodoViewModel) {
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
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textField.becomeFirstResponder()
    }

    // MARK: Binding

    private func bindViewModel() {
        viewModel.$isSubmitEnabled
            .sink { [weak self] isEnabled in
                self?.addButton.isEnabled = isEnabled
                self?.submitButton.isEnabled = isEnabled
            }
            .store(in: &cancellables)

        viewModel.$isSubmitting
            .sink { [weak self] isSubmitting in
                self?.submitButton.configuration?.showsActivityIndicator = isSubmitting
                // 提交中不可取消，避免取消後儲存仍完成而誤新增（AC-07）
                self?.cancelButton.isEnabled = !isSubmitting
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .sink { [weak self] message in
                self?.errorLabel.text = message
                self?.errorLabel.isHidden = message == nil
                if let message {
                    UIAccessibility.post(notification: .announcement, argument: message)
                }
            }
            .store(in: &cancellables)

        viewModel.didFinish
            .sink { [weak self] in self?.dismiss(animated: true) }
            .store(in: &cancellables)
    }

    private func titleDidChange() {
        // OQ-02 預設：限制輸入至 100 字；組字中（注音等）不截斷，避免打斷輸入法。
        if textField.markedTextRange == nil, let text = textField.text, text.count > AddTodoViewModel.maxTitleLength {
            textField.text = String(text.prefix(AddTodoViewModel.maxTitleLength))
        }
        viewModel.didChangeTitle(textField.text ?? "")
    }

    // MARK: Layout

    private func setUpViews() {
        view.backgroundColor = .systemGroupedBackground
        viewRespectsSystemMinimumLayoutMargins = false
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24)

        cancelButton.configuration?.title = "取消"
        cancelButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .touchUpInside)

        addButton.configuration?.title = "新增"
        addButton.addAction(UIAction { [weak self] _ in self?.viewModel.didTapSubmit() }, for: .touchUpInside)
        submitButton.addAction(UIAction { [weak self] _ in self?.viewModel.didTapSubmit() }, for: .touchUpInside)

        titleLabel.text = "新增任務"
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textAlignment = .center
        titleLabel.accessibilityTraits = .header

        fieldLabel.text = "任務名稱"
        fieldLabel.font = .preferredFont(forTextStyle: .subheadline)
        fieldLabel.adjustsFontForContentSizeCategory = true
        fieldLabel.textColor = .secondaryLabel

        fieldContainer.backgroundColor = .secondarySystemGroupedBackground
        fieldContainer.layer.cornerRadius = 12

        textField.placeholder = "輸入任務名稱"
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.clearButtonMode = .whileEditing
        textField.accessibilityLabel = "任務名稱"
        textField.addAction(UIAction { [weak self] _ in self?.titleDidChange() }, for: .editingChanged)

        helperLabel.text = "必填 · 一句話就夠了"
        helperLabel.font = .preferredFont(forTextStyle: .footnote)
        helperLabel.adjustsFontForContentSizeCategory = true
        helperLabel.textColor = .secondaryLabel
        helperLabel.numberOfLines = 0

        errorLabel.font = .preferredFont(forTextStyle: .footnote)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = .systemRed
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true

        let formStack = UIStackView(arrangedSubviews: [fieldLabel, fieldContainer, helperLabel, errorLabel])
        formStack.axis = .vertical
        formStack.spacing = 8

        for subview in [cancelButton, titleLabel, addButton, formStack, textField, submitButton] as [UIView] {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }
        view.addSubview(cancelButton)
        view.addSubview(titleLabel)
        view.addSubview(addButton)
        view.addSubview(formStack)
        view.addSubview(submitButton)
        fieldContainer.addSubview(textField)

        let margins = view.layoutMarginsGuide
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            cancelButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor, constant: -12),
            cancelButton.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 8),
            cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            addButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor, constant: 12),
            addButton.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            addButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: cancelButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: cancelButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: addButton.leadingAnchor, constant: -8),

            formStack.topAnchor.constraint(equalTo: cancelButton.bottomAnchor, constant: 24),
            formStack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),

            textField.topAnchor.constraint(equalTo: fieldContainer.topAnchor, constant: 8),
            textField.bottomAnchor.constraint(equalTo: fieldContainer.bottomAnchor, constant: -8),
            textField.leadingAnchor.constraint(equalTo: fieldContainer.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: fieldContainer.trailingAnchor, constant: -8),
            textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 38),

            submitButton.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            submitButton.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            submitButton.topAnchor.constraint(greaterThanOrEqualTo: formStack.bottomAnchor, constant: 16),
            // 跟隨鍵盤上緣，鍵盤開啟時主要操作仍可見（AC-14）
            submitButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
        ])
    }
}
