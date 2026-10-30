import UIKit

/// The chat supplies its native effect renderer without coupling the scratch surface to an account.
public protocol ScratchCardParticleEffect: AnyObject {
    var view: UIView { get }
    /// False means the effect is not cached yet; the surface can use local fragments.
    func emit(at point: CGPoint) -> Bool
    func stop()
}
