import UIKit

/// Premium loading view with Apple-level design
public class LoadingView: UIView {
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = UIColor(red: 0.4, green: 0.24, blue: 0.92, alpha: 1.0)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 20
        view.layer.cornerCurve = .continuous
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.1
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 20
        return view
    }()
    
    public init(message: String = "Loading...") {
        super.init(frame: .zero)
        messageLabel.text = message
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.3)
        
        addSubview(containerView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(messageLabel)
        
        containerView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 160),
            containerView.heightAnchor.constraint(equalToConstant: 160),
            
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            
            messageLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            messageLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20)
        ])
    }
    
    public func show(in view: UIView) {
        frame = view.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        alpha = 0
        view.addSubview(self)
        
        activityIndicator.startAnimating()
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }
    }
    
    public func hide(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
        } completion: { _ in
            self.activityIndicator.stopAnimating()
            self.removeFromSuperview()
            completion?()
        }
    }
}
