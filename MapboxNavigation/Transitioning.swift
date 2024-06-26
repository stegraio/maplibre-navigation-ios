import UIKit

class Interactor: UIPercentDrivenInteractiveTransition {
    var hasStarted = false
    var shouldFinish = false
}

class DismissAnimator: NSObject {}
extension DismissAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) else { return }
        guard let toVC = transitionContext.viewController(forKey: .to) else { return }
        let containerView = transitionContext.containerView
        
        let point = CGPoint(x: 0, y: toVC.view.bounds.maxY)
        let height = fromVC.view.bounds.height - toVC.view.frame.minY
        let finalFrame = CGRect(origin: point, size: CGSize(width: fromVC.view.bounds.width, height: height))
        
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: [.curveEaseInOut], animations: {
            fromVC.view.frame = finalFrame
            containerView.backgroundColor = .clear
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

class PresentAnimator: NSObject {}

extension PresentAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromVC = transitionContext.viewController(forKey: .from) else { return }
        let containerView = transitionContext.containerView
        let toView = transitionContext.view(forKey: .to)!
        let toVC = transitionContext.viewController(forKey: .to)!
        
        containerView.backgroundColor = .clear
        toView.frame = CGRect(x: 0, y: containerView.bounds.height,
                              width: containerView.bounds.width, height: containerView.bounds.midY)
        
        containerView.addSubview(toView)
        
        var height = toVC.view.bounds.height
        if let draggable = toVC as? DismissDraggable {
            height = draggable.draggableHeight
        }
        
        let finalFrame = CGRect(origin: CGPoint(x: 0, y: fromVC.view.bounds.height - height),
                                size: CGSize(width: fromVC.view.bounds.width, height: height))
        
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, options: [.curveEaseInOut], animations: {
            toView.frame = finalFrame
            containerView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        }, completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        })
    }
}

@objc protocol DismissDraggable: UIViewControllerTransitioningDelegate {
    var interactor: Interactor { get }
    var draggableHeight: CGFloat { get }
    @objc optional func handleDismissPan(_ sender: UIPanGestureRecognizer)
}

private extension Selector {
    static let handleDismissDrag = #selector(UIViewController.handleDismissPan(_:))
}

extension DismissDraggable where Self: UIViewController {
    func enableDraggableDismiss() {
        let pan = UIPanGestureRecognizer(target: self, action: .handleDismissDrag)
        view.addGestureRecognizer(pan)
    }
}

private extension UIViewController {
    @objc func handleDismissPan(_ sender: UIPanGestureRecognizer) {
        self.handlePan(sender)
    }
    
    func handlePan(_ sender: UIPanGestureRecognizer) {
        guard let vc = self as? DismissDraggable else { return }
        
        let finishThreshold: CGFloat = 0.4
        let translation = sender.translation(in: view)
        let progress = translation.y / view.bounds.height
        
        switch sender.state {
        case .began:
            vc.interactor.hasStarted = true
            dismiss(animated: true, completion: nil)
        case .changed:
            vc.interactor.shouldFinish = progress > finishThreshold
            vc.interactor.update(progress)
        case .cancelled:
            vc.interactor.hasStarted = false
            vc.interactor.cancel()
        case .ended:
            vc.interactor.hasStarted = false
            if vc.interactor.shouldFinish {
                vc.interactor.finish()
            } else {
                vc.interactor.cancel()
            }
        default:
            break
        }
    }
}
