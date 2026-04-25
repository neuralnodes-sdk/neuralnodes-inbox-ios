import UIKit

/// Premium error view with Apple-level design
public class ErrorView: UIView {
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
        imageView.image = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: config)
        imageView.tintColor = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let retryButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Try Again", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        
        // Premium shadow
        button.layer.shadowColor = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 0.4).cgColor
        button.layer.shadowOpacity = 1.0
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.layer.shadowRadius = 16
        
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        return stack
    }()
    
    public var onRetry: (() -> Void)?
    
    public init(title: String = "Something Went Wrong", message: String, showRetry: Bool = true) {
        super.init(frame: .zero)
        titleLabel.text = title
        messageLabel.text = message
        retryButton.isHidden = !showRetry
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemGroupedBackground
        
        // Icon container with gradient background
        let iconContainer = UIView()
        iconContainer.backgroundColor = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 0.1)
        iconContainer.layer.cornerRadius = 50
        iconContainer.layer.cornerCurve = .continuous
        
        iconContainer.addSubview(iconImageView)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 100),
            iconContainer.heightAnchor.constraint(equalToConstant: 100),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])
        
        stackView.addArrangedSubview(iconContainer)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(messageLabel)
        
        if !retryButton.isHidden {
            stackView.setCustomSpacing(30, after: messageLabel)
            stackView.addArrangedSubview(retryButton)
        }
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40),
            
            retryButton.widthAnchor.constraint(equalToConstant: 200),
            retryButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
    }
    
    @objc private func retryTapped() {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        // Scale animation
        UIView.animate(withDuration: 0.1, animations: {
            self.retryButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.retryButton.transform = .identity
            }
        }
        
        onRetry?()
    }
}
