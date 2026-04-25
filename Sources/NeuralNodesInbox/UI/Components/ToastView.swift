import UIKit

/// Premium toast notification with Apple-level design
public class ToastView: UIView {
    
    public enum Style {
        case success
        case error
        case info
        case warning
        
        var color: UIColor {
            switch self {
            case .success: return UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
            case .error: return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)
            case .info: return UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
            case .warning: return UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.2
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 20
        return view
    }()
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()
    
    public init(message: String, style: Style) {
        super.init(frame: .zero)
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
        iconImageView.image = UIImage(systemName: style.icon, withConfiguration: config)
        messageLabel.text = message
        containerView.backgroundColor = style.color
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(messageLabel)
        
        containerView.addSubview(stackView)
        addSubview(containerView)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    public static func show(message: String, style: Style, in view: UIView, duration: TimeInterval = 3.0) {
        let toast = ToastView(message: message, style: style)
        
        view.addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false
        
        let bottomConstraint = toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 100)
        
        NSLayoutConstraint.activate([
            toast.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            toast.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            bottomConstraint
        ])
        
        view.layoutIfNeeded()
        
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        switch style {
        case .success: generator.notificationOccurred(.success)
        case .error: generator.notificationOccurred(.error)
        case .warning: generator.notificationOccurred(.warning)
        case .info: generator.notificationOccurred(.success)
        }
        
        // Animate in
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: 20)
        
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            toast.alpha = 1
            toast.transform = .identity
            bottomConstraint.constant = -20
            view.layoutIfNeeded()
        }
        
        // Auto dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
                toast.alpha = 0
                toast.transform = CGAffineTransform(translationX: 0, y: 20)
            } completion: { _ in
                toast.removeFromSuperview()
            }
        }
    }
}
