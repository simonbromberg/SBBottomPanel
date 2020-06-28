//
//  SBBottomPanelViewController.swift
//  SBBottomPanel
//
//  Created by Simon Bromberg on 2020-06-24.
//  Copyright © 2020 SBromberg. All rights reserved.
//

import UIKit

protocol SBBottomPanelViewControllerDelegate: class {
    func bottomPanelDidFinish(_ controller: SBBottomPanelViewController)
}

class SBBottomPanelViewController: UIViewController {

    weak var delegate: SBBottomPanelViewControllerDelegate?

    @IBOutlet private var dragIndicator: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var arrowImageView: UIImageView!
    @IBOutlet private var headerContainerView: UIView!

    @IBOutlet private var tableView: UITableView!

    var isEnabled: Bool = true {
        didSet {
            view.isUserInteractionEnabled = isEnabled
            dragIndicator.isHidden = !isEnabled
            titleLabel.textColor = isEnabled ? .black : .gray
            arrowImageView.image = arrowImage
        }
    }

    enum SnapPosition {
        case peeking
        case short
        case full
    }


    private var currentYPosition: CGFloat {
        get {
            return view.frame.minY
        }
        set {
            view.frame.origin.y = newValue
        }
    }

    /// Should be set by presenting view controller
    var safeAreaMaxY: CGFloat?

    lazy var peekingYPosition: CGFloat = {
        let maxY = safeAreaMaxY ?? view.safeAreaLayoutGuide.layoutFrame.maxY
        return maxY - headerContainerView.frame.height + headerContainerView.frame.minY
    }()

    var shortFormYPosition: CGFloat {
        return UIScreen.main.bounds.height * 0.67
    }

    lazy var fullFormYPosition: CGFloat = {
        return UIApplication.shared.statusBarFrame.maxY
//        return view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0 // TODO: test this
    }()

    func yPositionForSnap(_ snap: SnapPosition) -> CGFloat {
        switch snap {
        case .peeking:
            return peekingYPosition
        case .short:
            return shortFormYPosition
        case .full:
            return fullFormYPosition
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        view.addGestureRecognizer(panGesture)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tappedNavBar(_:)))
        headerContainerView.addGestureRecognizer(tapGesture)

        addRoundedCorners()
    }

    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            respond(to: recognizer)
        default:
            let shortPosition = yPositionForSnap(.short)
            let fullPosition = yPositionForSnap(.full)
            let peekingPosition = yPositionForSnap(.peeking)

            //    Use velocity sensitivity value to restrict snapping
            let velocity = recognizer.velocity(in: view)

            if isVelocityWithinSensitivityRange(velocity.y) {
                /**
                If velocity is within the sensitivity range,
                snap to appropriate position.

                e.g. user can skip to peeking position from full
                instead of going to the short form first.
                */
                if velocity.y < 0 {
                    snap(to: .full)
                } else if nearest(to: currentYPosition, inValues: [fullPosition, peekingPosition]) == fullPosition
                    && currentYPosition < shortPosition {
                    snap(to: .short)
                } else {
                    snap(to: .peeking)
                }
            } else {
                let position = nearest(to: currentYPosition, inValues: [peekingPosition, shortPosition, fullPosition])

                if position == fullPosition {
                    snap(to: .full)
                } else if position == shortPosition {
                    snap(to: .short)
                } else {
                    snap(to: .peeking)
                }
            }
        }
    }

    @objc private func tappedNavBar(_ recognizer: UITapGestureRecognizer) {
        switch travelDirection(for: currentYPosition) {
        case .down:
            snap(to: .peeking)
        case .up:
            snap(to: .full)
        }
    }

    private enum Direction {
        case down, up

        var image: UIImage {
            switch self {
            case .up:
                return UIImage(systemName: "chevron.up")!
            case .down:
                return UIImage(systemName: "chevron.down")!
            }
        }
    }

    private func travelDirection(for position: CGFloat) -> Direction {
        switch position {
        case 0...yPositionForSnap(.full):
            return .down
        default:
            return .up
        }
    }

    private var arrowImage: UIImage? {
        return isEnabled ? travelDirection(for: currentYPosition).image : nil
    }

    /**
    Finds the nearest value to a given number out of a given array of float values

    - Parameters:
    - number: reference float we are trying to find the closest value to
    - values: array of floats we would like to compare against
    */
    func nearest(to number: CGFloat, inValues values: [CGFloat]) -> CGFloat {
        guard let nearestVal = values.min(by: { abs(number - $0) < abs(number - $1) })
            else { return number }
        return nearestVal
    }

    /**
    Check if the given velocity is within the sensitivity range
    */
    let snapMovementSensitivity = CGFloat(0.7)
    func isVelocityWithinSensitivityRange(_ velocity: CGFloat) -> Bool {
        return (abs(velocity) - (1000 * (1 - snapMovementSensitivity))) > 0
    }

    func respond(to panGestureRecognizer: UIPanGestureRecognizer) {
        let yDisplacement = panGestureRecognizer.translation(in: view).y

        adjust(to: currentYPosition + yDisplacement)

        panGestureRecognizer.setTranslation(.zero, in: view)
    }

    func snap(to snapPosition: SnapPosition, completion: ((_ finished: Bool) -> Void)? = nil) {
        UIView.animate(withDuration: 0.5, animations: { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.adjust(to: strongSelf.yPositionForSnap(snapPosition))
            strongSelf.updateContentInset()
            }, completion: completion
        )
    }

    private func adjust(to yPosition: CGFloat) {
        currentYPosition = max(yPosition, yPositionForSnap(.full))

        var alpha = CGFloat(1)

        let startFadeY = CGFloat(0.1) // within this percentage of peeking position will handle fading
        let peekingPosition = yPositionForSnap(.peeking)
        alpha = min(max((peekingPosition - yPosition)/(peekingPosition * startFadeY), 0), 1)

        tableView.alpha = alpha
        tableView.isUserInteractionEnabled = alpha > 0

        arrowImageView.image = arrowImage
    }

    private func addRoundedCorners() {
        // 1) drag indicator
        dragIndicator.layer.cornerRadius = dragIndicator.bounds.height / 2

        // 2) top right and left corners of view
        let radius = 20
        let path = UIBezierPath(roundedRect: view.bounds,
                                byRoundingCorners: [.topLeft, .topRight],
                                cornerRadii: CGSize(width: radius, height: radius))

        // Set path as a mask to display optional drag indicator view & rounded corners
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        view.layer.mask = mask

        // Improve performance by rasterizing the layer
        view.layer.shouldRasterize = true
        view.layer.rasterizationScale = UIScreen.main.scale
    }

    private func updateContentInset() {
        let bottom = view.frame.height + currentYPosition - (safeAreaMaxY ?? UIScreen.main.bounds.height)
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
    }
}
