import Foundation

// MARK: - Lifecycle

/// Protocol which view model can confom to react on cell events
/// Other UICollectionViewDelegate highly dependent on UIKit
/// so it looks better to decouple this logic from view models
public protocol CollectionComponentViewModelLifecycleProtocol {
    func shouldHighlight(indexPath: IndexPath) -> Bool
    func didHighlight(indexPath: IndexPath)
    func didUnhighlight(indexPath: IndexPath)

    func shouldSelect(indexPath: IndexPath) -> Bool
    func didSelect(indexPath: IndexPath)
    func shouldDeselect(indexPath: IndexPath) -> Bool
    func didDeselect(indexPath: IndexPath)

    func willDisplay(indexPath: IndexPath)
    func didEndDisplay(indexPath: IndexPath)
}

public extension CollectionComponentViewModelLifecycleProtocol {
    func shouldHighlight(indexPath: IndexPath) -> Bool { return true }
    func didHighlight(indexPath: IndexPath) { }
    func didUnhighlight(indexPath: IndexPath) { }

    func shouldSelect(indexPath: IndexPath) -> Bool { return true }
    func didSelect(indexPath: IndexPath) { }
    func shouldDeselect(indexPath: IndexPath) -> Bool { return true }
    func didDeselect(indexPath: IndexPath) { }

    func willDisplay(indexPath: IndexPath) { }
    func didEndDisplay(indexPath: IndexPath) { }
}

// MARK: - Updates

public protocol ReloadTokenProtocol {
    func reload(animated: Bool)
}

public extension ReloadTokenProtocol {
    func reload() {
        reload(animated: false)
    }
}

struct BlockReloadToken: ReloadTokenProtocol {
    let reloadBlock: (Bool) -> Void
    func reload(animated: Bool) {
        reloadBlock(animated)
    }
}

/// If view model's view needs to be redrawn (e.g. content changed and size is invalid anymore)
/// you can use the token to trigger an underlying cell reload
public protocol CollectionComponentViewModelReloadableProtocol {
    func storeReloadToken(_ token: ReloadTokenProtocol)
}

// MARK: - Size calculation

/// If view model conforms this protocol - calculated size will be cached and reused
/// otherwise - it will be recalculated all the time and might cause performance issues
public protocol CollectionComponentViewModelHashableContentProtocol {
    var contentHash: Int { get }
}
