import UIKit

/// Connection status banner with Apple-level design
public class ConnectionBanner: UIView {
    
    public enum Status {
        case connected
        case connecting
        case disconnected
        case error
        
        var color: UIColor {
            switch self {
            case .connected: return UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0)
            case .connecting: return UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
            case .disconnected: return .systemGray
            case .error: return UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)
            }
        }
        
        var icon: String {
            switch self {
            case .connected: return "checkmark.circle.fill"
            case .connecting: return "arrow.clockwise"
            case .disconnected: return "wifi.slash"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
        
        var message: String {
            switch self {
            case .connected: return "Connected"
            case .connecting: return "Connecting..."
            case .disconnected: return "Disconnected"
            case .error: return "Connection Error"
            }
        }
    }
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        return stack
    }()
    
    private var currentStatus: Status = .connected
    
    public init() {
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        
        stackView.addArrangedSubview(iconImageView)
        stackView.addArrangedSubview(messageLabel)
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    public func updateStatus(_ status: Status, animated: Bool = true) {
        currentStatus = status
        
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        iconImageView.image = UIImage(systemName: status.icon, withConfiguration: config)
        messageLabel.text = status.message
        
        let updateBlock = {
            self.backgroundColor = status.color
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                updateBlock()
            }
        } else {
            updateBlock()
        }
        
        // Rotate icon for connecting state
        if status == .connecting {
            startRotationAnimation()
        } else {
            iconImageView.layer.removeAllAnimations()
        }
    }
    
    private func startRotationAnimation() {
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.toValue = NSNumber(value: Double.pi * 2)
        rotation.duration = 1.0
        rotation.isCumulative = true
        rotation.repeatCount = .infinity
        iconImageView.layer.add(rotation, forKey: "rotationAnimation")
    }
    
    public func show(in view: UIView, duration: TimeInterval = 0.3) {
        frame = CGRect(x: 0, y: -50, width: view.bounds.width, height: 44)
        autoresizingMask = [.flexibleWidth]
        view.addSubview(self)
        
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
            self.frame.origin.y = 0
        }
    }
    
    public func hide(duration: TimeInterval = 0.3, completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration, delay: 0, options: .curveEaseIn) {
            self.frame.origin.y = -50
        } completion: { _ in
            self.removeFromSuperview()
            completion?()
        }
    }
    
    public func autoHide(after delay: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.hide()
        }
    }
}
