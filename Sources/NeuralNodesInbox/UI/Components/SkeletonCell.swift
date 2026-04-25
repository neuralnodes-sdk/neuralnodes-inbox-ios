import UIKit

/// Skeleton loading cell with shimmer animation
class SkeletonCell: UITableViewCell {
    
    private let cardView = UIView()
    private let iconSkeleton = UIView()
    private let nameSkeleton = UIView()
    private let messageSkeleton = UIView()
    private let timeSkeleton = UIView()
    
    private let gradientLayer = CAGradientLayer()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        startShimmerAnimation()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none
        
        // Card
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 16
        cardView.layer.cornerCurve = .continuous
        
        // Skeleton views
        [iconSkeleton, nameSkeleton, messageSkeleton, timeSkeleton].forEach {
            $0.backgroundColor = .systemGray5
            $0.layer.cornerRadius = 8
            $0.layer.cornerCurve = .continuous
        }
        
        iconSkeleton.layer.cornerRadius = 26
        
        contentView.addSubview(cardView)
        cardView.addSubview(iconSkeleton)
        cardView.addSubview(nameSkeleton)
        cardView.addSubview(messageSkeleton)
        cardView.addSubview(timeSkeleton)
        
        [cardView, iconSkeleton, nameSkeleton, messageSkeleton, timeSkeleton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.heightAnchor.constraint(equalToConstant: 76),
            
            iconSkeleton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconSkeleton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconSkeleton.widthAnchor.constraint(equalToConstant: 52),
            iconSkeleton.heightAnchor.constraint(equalToConstant: 52),
            
            nameSkeleton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 14),
            nameSkeleton.leadingAnchor.constraint(equalTo: iconSkeleton.trailingAnchor, constant: 12),
            nameSkeleton.widthAnchor.constraint(equalToConstant: 120),
            nameSkeleton.heightAnchor.constraint(equalToConstant: 16),
            
            messageSkeleton.topAnchor.constraint(equalTo: nameSkeleton.bottomAnchor, constant: 8),
            messageSkeleton.leadingAnchor.constraint(equalTo: nameSkeleton.leadingAnchor),
            messageSkeleton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -60),
            messageSkeleton.heightAnchor.constraint(equalToConstant: 14),
            
            timeSkeleton.topAnchor.constraint(equalTo: nameSkeleton.topAnchor),
            timeSkeleton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            timeSkeleton.widthAnchor.constraint(equalToConstant: 50),
            timeSkeleton.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        // Setup gradient
        gradientLayer.colors = [
            UIColor.systemGray5.cgColor,
            UIColor.systemGray4.cgColor,
            UIColor.systemGray5.cgColor
        ]
        gradientLayer.locations = [0, 0.5, 1]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        
        cardView.layer.addSublayer(gradientLayer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = cardView.bounds
    }
    
    private func startShimmerAnimation() {
        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = 1.5
        animation.repeatCount = .infinity
        gradientLayer.add(animation, forKey: "shimmer")
    }
}
