import UIKit

/// Premium chat view controller with Apple-level design
public class ChatViewController: UIViewController {
    
    private let conversation: Conversation
    private let apiClient: APIClient
    private let realtimeClient: RealtimeClient
    private let config: SDKConfig
    
    private var messages: [Message] = []
    private var inputBottomConstraint: NSLayoutConstraint?
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        table.delegate = self
        table.dataSource = self
        table.register(MessageCell.self, forCellReuseIdentifier: "MessageCell")
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.transform = CGAffineTransform(scaleX: 1, y: -1)
        table.contentInset = UIEdgeInsets(top: 12, left: 0, bottom: 12, right: 0)
        table.keyboardDismissMode = .interactive
        return table
    }()
    
    private lazy var inputContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        
        // Premium shadow
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: -2)
        view.layer.shadowRadius = 12
        
        return view
    }()
    
    private lazy var inputBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 22
        view.layer.cornerCurve = .continuous
        return view
    }()
    
    private lazy var inputField: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        textView.isScrollEnabled = false
        textView.delegate = self
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Message"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .tertiaryLabel
        return label
    }()
    
    private lazy var sendButton: UIButton = {
        let button = UIButton(type: .system)
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        button.setImage(UIImage(systemName: "arrow.up.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        button.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        button.alpha = 0.5
        button.isEnabled = false
        
        return button
    }()
    
    // MARK: - Initialization
    
    public init(conversation: Conversation, apiClient: APIClient, realtimeClient: RealtimeClient, config: SDKConfig) {
        self.conversation = conversation
        self.apiClient = apiClient
        self.realtimeClient = realtimeClient
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadMessages()
        subscribeToMessages()
        markAsRead()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = conversation.displayName
        view.backgroundColor = .systemGroupedBackground
        
        // Navigation bar styling
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // Menu button
        let menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "ellipsis.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)), for: .normal)
        menuButton.tintColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = createMenu()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: menuButton)
        
        // Layout
        view.addSubview(tableView)
        view.addSubview(inputContainer)
        inputContainer.addSubview(inputBackgroundView)
        inputBackgroundView.addSubview(inputField)
        inputBackgroundView.addSubview(placeholderLabel)
        inputContainer.addSubview(sendButton)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        inputBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        inputField.translatesAutoresizingMaskIntoConstraints = false
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Store the bottom constraint for keyboard handling
        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),
            
            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBottomConstraint!,
            
            inputBackgroundView.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputBackgroundView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            inputBackgroundView.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            inputBackgroundView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -12),
            inputBackgroundView.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            
            inputField.topAnchor.constraint(equalTo: inputBackgroundView.topAnchor),
            inputField.leadingAnchor.constraint(equalTo: inputBackgroundView.leadingAnchor),
            inputField.trailingAnchor.constraint(equalTo: inputBackgroundView.trailingAnchor),
            inputField.bottomAnchor.constraint(equalTo: inputBackgroundView.bottomAnchor),
            inputField.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            
            placeholderLabel.leadingAnchor.constraint(equalTo: inputField.leadingAnchor, constant: 17),
            placeholderLabel.topAnchor.constraint(equalTo: inputField.topAnchor, constant: 10),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: inputBackgroundView.bottomAnchor, constant: -2),
            sendButton.widthAnchor.constraint(equalToConstant: 40),
            sendButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func createMenu() -> UIMenu {
        let markRead = UIAction(title: "Mark as Read", image: UIImage(systemName: "envelope.open.fill")) { [weak self] _ in
            self?.markAsRead()
        }
        
        let markActive = UIAction(title: "Mark as Active", image: UIImage(systemName: "circle.fill")) { [weak self] _ in
            self?.updateStatus(to: "active")
        }
        
        let markPending = UIAction(title: "Mark as Pending", image: UIImage(systemName: "clock.fill")) { [weak self] _ in
            self?.updateStatus(to: "pending")
        }
        
        let markResolved = UIAction(title: "Mark as Resolved", image: UIImage(systemName: "checkmark.circle.fill")) { [weak self] _ in
            self?.updateStatus(to: "resolved")
        }
        
        return UIMenu(children: [markRead, markActive, markPending, markResolved])
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    // MARK: - Data
    
    private func loadMessages() {
        Task {
            do {
                messages = try await apiClient.getMessages(conversationId: conversation.id)
                await MainActor.run {
                    tableView.reloadData()
                    scrollToBottom(animated: false)
                }
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
    
    private func subscribeToMessages() {
        realtimeClient.subscribeToConversation(conversation.id) { [weak self] message in
            guard let self = self else { return }
            Task { @MainActor in
                self.messages.insert(message, at: 0)
                self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        }
    }
    
    private func markAsRead() {
        Task {
            try? await apiClient.markAsRead(conversationId: conversation.id)
        }
    }
    
    private func updateStatus(to status: String) {
        Task {
            do {
                try await apiClient.updateStatus(conversationId: conversation.id, status: status)
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func sendTapped() {
        guard let text = inputField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        inputField.text = ""
        placeholderLabel.isHidden = false
        updateSendButton()
        inputField.resignFirstResponder()
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        Task {
            do {
                let message = try await apiClient.sendMessage(conversationId: conversation.id, text: text)
                await MainActor.run {
                    messages.insert(message, at: 0)
                    tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                    scrollToBottom(animated: true)
                }
            } catch {
                await MainActor.run {
                    inputField.text = text
                    placeholderLabel.isHidden = true
                    updateSendButton()
                    showError(error)
                }
            }
        }
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
        inputBottomConstraint?.constant = -keyboardHeight
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        
        scrollToBottom(animated: true)
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else {
            return
        }
        
        inputBottomConstraint?.constant = 0
        
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Helpers
    
    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: animated)
    }
    
    private func updateSendButton() {
        let hasText = !(inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        
        UIView.animate(withDuration: 0.2) {
            self.sendButton.alpha = hasText ? 1.0 : 0.5
            self.sendButton.transform = hasText ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
        
        sendButton.isEnabled = hasText
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ChatViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MessageCell", for: indexPath) as! MessageCell
        cell.configure(with: messages[indexPath.row])
        cell.transform = CGAffineTransform(scaleX: 1, y: -1)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - UITextViewDelegate

extension ChatViewController: UITextViewDelegate {
    public func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSendButton()
    }
}

// MARK: - Premium Message Cell

class MessageCell: UITableViewCell {
    
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let senderLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        bubbleView.layer.cornerRadius = 18
        bubbleView.layer.cornerCurve = .continuous
        
        messageLabel.numberOfLines = 0
        messageLabel.font = .systemFont(ofSize: 16, weight: .regular)
        
        timeLabel.font = .systemFont(ofSize: 12, weight: .medium)
        
        senderLabel.font = .systemFont(ofSize: 13, weight: .medium)
        
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(senderLabel)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(timeLabel)
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        senderLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
    }
    
    func configure(with message: Message) {
        messageLabel.text = message.messageText
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        timeLabel.text = formatter.string(from: message.createdAt)
        
        // Remove old constraints
        NSLayoutConstraint.deactivate(bubbleView.constraints)
        NSLayoutConstraint.deactivate(senderLabel.constraints)
        NSLayoutConstraint.deactivate(messageLabel.constraints)
        NSLayoutConstraint.deactivate(timeLabel.constraints)
        
        if message.isFromAgent {
            // Agent message (right side)
            bubbleView.backgroundColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
            messageLabel.textColor = .white
            timeLabel.textColor = .white.withAlphaComponent(0.8)
            senderLabel.isHidden = true
            
            // Premium shadow
            bubbleView.layer.shadowColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 0.4).cgColor
            bubbleView.layer.shadowOpacity = 1.0
            bubbleView.layer.shadowOffset = CGSize(width: 0, height: 4)
            bubbleView.layer.shadowRadius = 12
            
            NSLayoutConstraint.activate([
                bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
                bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
                
                messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 10),
                messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
                messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
                
                timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 6),
                timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
                timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10)
            ])
        } else {
            // User message (left side)
            bubbleView.backgroundColor = .secondarySystemGroupedBackground
            messageLabel.textColor = .label
            timeLabel.textColor = .secondaryLabel
            senderLabel.isHidden = false
            senderLabel.text = message.displaySenderName
            senderLabel.textColor = .secondaryLabel
            
            bubbleView.layer.shadowColor = UIColor.black.cgColor
            bubbleView.layer.shadowOpacity = 0.05
            bubbleView.layer.shadowOffset = CGSize(width: 0, height: 2)
            bubbleView.layer.shadowRadius = 8
            
            NSLayoutConstraint.activate([
                bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
                bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
                bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
                
                senderLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
                senderLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
                senderLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
                
                messageLabel.topAnchor.constraint(equalTo: senderLabel.bottomAnchor, constant: 4),
                messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
                messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -14),
                
                timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 6),
                timeLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 14),
                timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -10)
            ])
        }
    }
}
