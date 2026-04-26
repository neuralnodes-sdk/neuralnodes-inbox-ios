import UIKit

/// Main inbox view controller with Apple-level design
public class InboxViewController: UIViewController {
    
    private let apiClient: APIClient
    private let realtimeClient: RealtimeClient
    private let config: SDKConfig
    
    private var conversations: [Conversation] = []
    private var filteredConversations: [Conversation] = []
    private var currentFilter: String? = nil
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.delegate = self
        table.dataSource = self
        table.register(ConversationCell.self, forCellReuseIdentifier: "ConversationCell")
        table.separatorStyle = .none
        table.backgroundColor = .systemGroupedBackground
        table.refreshControl = refreshControl
        table.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        return table
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.tintColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        control.addTarget(self, action: #selector(refreshConversations), for: .valueChanged)
        return control
    }()
    
    private lazy var filterSegment: UISegmentedControl = {
        let items = ["All", "Active", "Pending", "Resolved"]
        let segment = UISegmentedControl(items: items)
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        
        // Premium styling
        segment.backgroundColor = .secondarySystemGroupedBackground
        segment.selectedSegmentTintColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        segment.setTitleTextAttributes([
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
        segment.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)
        
        return segment
    }()
    
    private lazy var filterContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .systemBackground
        
        // Add subtle shadow
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.05
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.layer.shadowRadius = 3
        
        return container
    }()
    
    private lazy var emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Icon with gradient
        let iconContainer = UIView()
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 0.1).cgColor,
            UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 0.05).cgColor
        ]
        gradientLayer.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        gradientLayer.cornerRadius = 50
        iconContainer.layer.addSublayer(gradientLayer)
        
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        let iconImage = UIImageView(image: UIImage(systemName: "tray", withConfiguration: iconConfig))
        iconImage.tintColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        iconImage.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImage)
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 100),
            iconContainer.heightAnchor.constraint(equalToConstant: 100),
            iconImage.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImage.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "No Conversations"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .label
        
        let messageLabel = UILabel()
        messageLabel.text = "Conversations will appear here"
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        
        stackView.addArrangedSubview(iconContainer)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])
        
        return view
    }()
    
    // MARK: - Initialization
    
    public init(apiClient: APIClient, realtimeClient: RealtimeClient, config: SDKConfig) {
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
        loadConversations()
        subscribeToUpdates()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Inbox"
        view.backgroundColor = .systemGroupedBackground
        
        // Navigation bar styling
        navigationController?.navigationBar.prefersLargeTitles = true
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.label
        ]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        // Close button with premium styling
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)), for: .normal)
        closeButton.tintColor = .secondaryLabel
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: closeButton)
        
        // Add filter container
        view.addSubview(filterContainer)
        filterContainer.addSubview(filterSegment)
        view.addSubview(tableView)
        view.addSubview(emptyStateView)
        
        filterContainer.translatesAutoresizingMaskIntoConstraints = false
        filterSegment.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            filterContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            filterContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filterContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filterContainer.heightAnchor.constraint(equalToConstant: 60),
            
            filterSegment.centerYAnchor.constraint(equalTo: filterContainer.centerYAnchor),
            filterSegment.leadingAnchor.constraint(equalTo: filterContainer.leadingAnchor, constant: 16),
            filterSegment.trailingAnchor.constraint(equalTo: filterContainer.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: filterContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            emptyStateView.topAnchor.constraint(equalTo: filterContainer.bottomAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func refreshConversations() {
        loadConversations()
    }
    
    @objc private func filterChanged() {
        let filters = [nil, "active", "pending", "resolved"]
        currentFilter = filters[filterSegment.selectedSegmentIndex]
        applyFilter()
    }
    
    // MARK: - Data
    
    private func loadConversations() {
        Task {
            do {
                let filters = ConversationFilters(status: currentFilter)
                conversations = try await apiClient.getConversations(filters: filters)
                applyFilter()
                
                await MainActor.run {
                    tableView.reloadData()
                    refreshControl.endRefreshing()
                    updateEmptyState()
                }
            } catch {
                await MainActor.run {
                    refreshControl.endRefreshing()
                    showError(error)
                }
            }
        }
    }
    
    private func applyFilter() {
        if let filter = currentFilter {
            filteredConversations = conversations.filter { $0.status == filter }
        } else {
            filteredConversations = conversations
        }
    }
    
    private func updateEmptyState() {
        emptyStateView.isHidden = !filteredConversations.isEmpty
        tableView.isHidden = filteredConversations.isEmpty
    }
    
    private func subscribeToUpdates() {
        // Get clientId from API client
        guard let clientId = apiClient.getClientId() else {
            print("⚠️ Cannot subscribe to inbox updates - clientId not available")
            return
        }
        
        realtimeClient.subscribeToInbox(clientId: clientId) { [weak self] in
            self?.loadConversations()
        }
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

extension InboxViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredConversations.count
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ConversationCell", for: indexPath) as! ConversationCell
        cell.configure(with: filteredConversations[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension InboxViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        let conversation = filteredConversations[indexPath.row]
        let chatVC = ChatViewController(
            conversation: conversation,
            apiClient: apiClient,
            realtimeClient: realtimeClient,
            config: config
        )
        navigationController?.pushViewController(chatVC, animated: true)
    }
    
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 88
    }
}

// MARK: - Premium Conversation Cell

class ConversationCell: UITableViewCell {
    
    private let cardView = UIView()
    private let iconContainer = UIView()
    private let iconLabel = UILabel()
    private let nameLabel = UILabel()
    private let messageLabel = UILabel()
    private let timeLabel = UILabel()
    private let badgeLabel = UILabel()
    private let statusDot = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Card with premium styling
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.05
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 8
        
        // Icon container with gradient
        iconContainer.layer.cornerRadius = 26
        iconContainer.layer.cornerCurve = .continuous
        
        iconLabel.font = .systemFont(ofSize: 24)
        iconLabel.textAlignment = .center
        
        nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        nameLabel.textColor = .label
        
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 2
        
        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = .tertiaryLabel
        
        badgeLabel.backgroundColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        badgeLabel.textColor = .white
        badgeLabel.font = .systemFont(ofSize: 12, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.clipsToBounds = true
        
        statusDot.layer.cornerRadius = 4
        
        contentView.addSubview(cardView)
        cardView.addSubview(iconContainer)
        iconContainer.addSubview(iconLabel)
        cardView.addSubview(nameLabel)
        cardView.addSubview(messageLabel)
        cardView.addSubview(timeLabel)
        cardView.addSubview(badgeLabel)
        cardView.addSubview(statusDot)
        
        [cardView, iconContainer, iconLabel, nameLabel, messageLabel, timeLabel, badgeLabel, statusDot].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            
            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 52),
            iconContainer.heightAnchor.constraint(equalToConstant: 52),
            
            iconLabel.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconLabel.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),
            
            messageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            messageLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            messageLabel.trailingAnchor.constraint(equalTo: badgeLabel.leadingAnchor, constant: -8),
            messageLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -14),
            
            timeLabel.topAnchor.constraint(equalTo: nameLabel.topAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            
            statusDot.centerYAnchor.constraint(equalTo: messageLabel.firstBaselineAnchor),
            statusDot.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8),
            
            badgeLabel.centerYAnchor.constraint(equalTo: messageLabel.centerYAnchor),
            badgeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badgeLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with conversation: Conversation) {
        iconLabel.text = conversation.channelIcon
        nameLabel.text = conversation.displayName
        messageLabel.text = conversation.lastMessage ?? "No messages"
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        timeLabel.text = formatter.localizedString(for: conversation.updatedAt, relativeTo: Date())
        
        // Channel color
        let channelColor: UIColor
        switch conversation.channel {
        case "webchat": channelColor = UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
        case "whatsapp": channelColor = UIColor(red: 0.15, green: 0.82, blue: 0.40, alpha: 1.0)
        case "telegram": channelColor = UIColor(red: 0.0, green: 0.53, blue: 0.80, alpha: 1.0)
        case "email": channelColor = UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1.0)
        default: channelColor = .systemBlue
        }
        
        iconContainer.backgroundColor = channelColor.withAlphaComponent(0.12)
        iconLabel.textColor = channelColor
        
        // Status color
        let statusColor: UIColor
        switch conversation.status {
        case "active": statusColor = UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
        case "pending": statusColor = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
        case "resolved": statusColor = .systemGray
        default: statusColor = .systemGray
        }
        
        statusDot.backgroundColor = statusColor
        
        // Badge
        if conversation.unreadCount > 0 {
            badgeLabel.isHidden = false
            badgeLabel.text = "\(conversation.unreadCount)"
            statusDot.isHidden = true
        } else {
            badgeLabel.isHidden = true
            statusDot.isHidden = false
        }
        
        // Accessibility
        isAccessibilityElement = true
        accessibilityLabel = "\(conversation.displayName), \(conversation.channel), \(conversation.status)"
        if conversation.unreadCount > 0 {
            accessibilityLabel = (accessibilityLabel ?? "") + ", \(conversation.unreadCount) unread messages"
        }
        accessibilityHint = "Double tap to open conversation"
        accessibilityTraits = .button
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.cardView.transform = highlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            self.cardView.alpha = highlighted ? 0.9 : 1.0
        }
    }
}
