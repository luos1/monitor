import ReplayKit
import SwiftUI
import UIKit

struct BroadcastPickerButton: UIViewRepresentable {
    let preferredExtension: String

    func makeUIView(context: Context) -> BroadcastPickerContainerView {
        let view = BroadcastPickerContainerView()
        view.preferredExtension = preferredExtension
        return view
    }

    func updateUIView(_ uiView: BroadcastPickerContainerView, context: Context) {
        uiView.preferredExtension = preferredExtension
    }
}

final class BroadcastPickerContainerView: UIView {
    private let picker = RPSystemBroadcastPickerView(frame: .zero)
    private let titleLabel = UILabel()
    private let iconView = UIImageView()

    var preferredExtension: String = "" {
        didSet {
            picker.preferredExtension = preferredExtension
            configurePickerButton()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .systemRed
        layer.cornerRadius = 18
        layer.masksToBounds = true

        iconView.image = UIImage(
            systemName: "record.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        )
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        titleLabel.text = "전체 화면 방송 시작"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        picker.tintColor = .clear
        picker.isUserInteractionEnabled = true
        addSubview(picker)

        isAccessibilityElement = false
        accessibilityTraits = [.button]
        accessibilityLabel = "iPad 현재 화면 방송 시작"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let iconSize: CGFloat = 30
        let spacing: CGFloat = 10
        let textWidth = titleLabel.intrinsicContentSize.width
        let totalWidth = iconSize + spacing + textWidth
        let startX = max((bounds.width - totalWidth) / 2, 16)
        let centerY = bounds.midY

        iconView.frame = CGRect(
            x: startX,
            y: centerY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        titleLabel.frame = CGRect(
            x: startX + iconSize + spacing,
            y: 0,
            width: min(textWidth, bounds.width - startX - iconSize - spacing - 16),
            height: bounds.height
        )

        picker.frame = bounds
        configurePickerButton()
        bringSubviewToFront(picker)
    }

    private func configurePickerButton() {
        picker.preferredExtension = preferredExtension

        for button in broadcastButtons(in: picker) {
            button.frame = picker.bounds
            button.backgroundColor = .clear
            button.tintColor = .clear
            button.setTitle(nil, for: .normal)
            button.setImage(nil, for: .normal)
            button.isUserInteractionEnabled = true
            button.accessibilityLabel = "전체 화면 방송 시작"
        }
    }

    private func broadcastButtons(in view: UIView) -> [UIButton] {
        var buttons: [UIButton] = []

        for subview in view.subviews {
            if let button = subview as? UIButton {
                buttons.append(button)
            }
            buttons.append(contentsOf: broadcastButtons(in: subview))
        }

        return buttons
    }
}
