import UIKit

@MainActor protocol CollectionViewDelegateProtocol: UICollectionViewDelegateFlowLayout {
    var scrollViewDelegate: UIScrollViewDelegate? { get set }
    var flowLayoutDelegate: UICollectionViewDelegateFlowLayout? { get set }
}

@MainActor final class CollectionViewDelegate: NSObject, CollectionViewDelegateProtocol {
    weak var scrollViewDelegate: UIScrollViewDelegate?
    weak var flowLayoutDelegate: UICollectionViewDelegateFlowLayout?

    private let viewModelProvider: ViewModelAtIndexPathProvider
    private let sizeProvider: CellSizeAtIndexPathProvider

    init(
        viewModelProvider: @escaping ViewModelAtIndexPathProvider,
        sizeProvider: @escaping CellSizeAtIndexPathProvider
    ) {
        self.viewModelProvider = viewModelProvider
        self.sizeProvider = sizeProvider
        #if DEBUG
        Self.checkMethodsExistance
        #endif
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(
        _ collectionView: UICollectionView,
        shouldHighlightItemAt indexPath: IndexPath
    ) -> Bool {
        delegate(for: indexPath)?.shouldHighlight(indexPath: indexPath) ?? true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didHighlightItemAt indexPath: IndexPath
    ) {
        delegate(for: indexPath)?.didHighlight(indexPath: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didUnhighlightItemAt indexPath: IndexPath
    ) {
        delegate(for: indexPath)?.didUnhighlight(indexPath: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldSelectItemAt indexPath: IndexPath
    ) -> Bool {
        delegate(for: indexPath)?.shouldSelect(indexPath: indexPath) ?? true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        delegate(for: indexPath)?.didSelect(indexPath: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        shouldDeselectItemAt indexPath: IndexPath
    ) -> Bool {
        delegate(for: indexPath)?.shouldDeselect(indexPath: indexPath) ?? true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didDeselectItemAt indexPath: IndexPath
    ) {
        delegate(for: indexPath)?.didDeselect(indexPath: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let delegate = delegate(for: indexPath) else { return }
        cell.appearanceDelegate = delegate
        delegate.willDisplay(indexPath: indexPath)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        cell.appearanceDelegate?.didEndDisplay(indexPath: indexPath)
        cell.appearanceDelegate = nil
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidScroll?(scrollView)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidZoom?(scrollView)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewWillBeginDragging?(scrollView)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        self.scrollViewDelegate?.scrollViewWillEndDragging?(
            scrollView,
            withVelocity: velocity,
            targetContentOffset: targetContentOffset
        )
    }

    func scrollViewDidEndDragging(
        _ scrollView: UIScrollView,
        willDecelerate decelerate: Bool
    ) {
        self.scrollViewDelegate?.scrollViewDidEndDragging?(
            scrollView,
            willDecelerate: decelerate
        )
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewWillBeginDecelerating?(scrollView)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidEndDecelerating?(scrollView)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.scrollViewDelegate?.viewForZooming?(in: scrollView)
    }

    func scrollViewWillBeginZooming(
        _ scrollView: UIScrollView,
        with view: UIView?
    ) {
        self.scrollViewDelegate?.scrollViewWillBeginZooming?(
            scrollView,
            with: view
        )
    }

    func scrollViewDidEndZooming(
        _ scrollView: UIScrollView,
        with view: UIView?,
        atScale scale: CGFloat
    ) {
        self.scrollViewDelegate?.scrollViewDidEndZooming?(
            scrollView,
            with: view,
            atScale: scale
        )
    }

    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        assert(self.scrollViewDelegate != nil, "UIScrollViewDelegate not found")
        return self.scrollViewDelegate?.scrollViewShouldScrollToTop?(scrollView) ?? false
    }

    func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidScrollToTop?(scrollView)
    }

    func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
        self.scrollViewDelegate?.scrollViewDidChangeAdjustedContentInset?(scrollView)
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let externalSize: CGSize? = sizeProvider(
            collectionView,
            collectionViewLayout,
            indexPath
        )
        return externalSize ?? self.flowLayoutDelegate?.collectionView?(
            collectionView,
            layout: collectionViewLayout,
            sizeForItemAt: indexPath
        ) ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize ?? .zero
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        self.flowLayoutDelegate?.collectionView?(
            collectionView,
            layout: collectionViewLayout,
            insetForSectionAt: section
        ) ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumLineSpacingForSectionAt section: Int
    ) -> CGFloat {
        self.flowLayoutDelegate?.collectionView?(
            collectionView,
            layout: collectionViewLayout,
            minimumLineSpacingForSectionAt: section
        ) ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        minimumInteritemSpacingForSectionAt section: Int
    ) -> CGFloat {
        self.flowLayoutDelegate?.collectionView?(
            collectionView,
            layout: collectionViewLayout,
            minimumInteritemSpacingForSectionAt: section
        ) ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing ?? 0
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        self.flowLayoutDelegate?.collectionView?(
            collectionView,
            layout: collectionViewLayout,
            referenceSizeForHeaderInSection: section
        ) ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.headerReferenceSize ?? .zero
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForFooterInSection section: Int
    ) -> CGSize {
        self.flowLayoutDelegate?.collectionView?(
            collectionView,
            layout: collectionViewLayout,
            referenceSizeForFooterInSection: section
        ) ?? (collectionViewLayout as? UICollectionViewFlowLayout)?.footerReferenceSize ?? .zero
    }

    // MARK: - Private

    private static let scrollViewDelegateSelectors = getProtocolSelectors(
        from: UIScrollViewDelegate.self
    )

    private static let flowLayoutDelegateSelectors = getProtocolSelectors(
        from: UICollectionViewDelegateFlowLayout.self
    )

    private static let collectionViewDelegateSelectors = getProtocolSelectors(
        from: UICollectionViewDelegate.self
    )

    private static let selfCollectionViewDelegateSelectors: Set<Selector> = {
        selfSelectors.intersection(collectionViewDelegateSelectors)
    }()

    private static let selfSelectors = getClassSelectors(
        from: CollectionViewDelegate.self
    )

    #if DEBUG
    private static let selfScrollViewDelegateSelectors: Set<Selector> = {
        selfSelectors.intersection(scrollViewDelegateSelectors)
    }()

    private static let selfFlowLayoutDelegateSelectors: Set<Selector> = {
        selfSelectors.intersection(flowLayoutDelegateSelectors)
    }()

    private static let checkMethodsExistance: Void = {
        let missingScrollViewMethods = scrollViewDelegateSelectors.subtracting(
            selfScrollViewDelegateSelectors
        )
        assert(
            missingScrollViewMethods.count == 0,
            "Please implement absent methods: \(missingScrollViewMethods)"
        )
        let missingFlowLayoutDelegateMethods = flowLayoutDelegateSelectors.subtracting(
            selfFlowLayoutDelegateSelectors
        )
        assert(
            missingFlowLayoutDelegateMethods.count == 0,
            "Please implement absent methods: \(missingFlowLayoutDelegateMethods)"
        )
    }()
    #endif

    private static let sizeSelector = #selector(
        UICollectionViewDelegateFlowLayout.collectionView(_:layout:sizeForItemAt:)
    )

    private func delegate(for indexPath: IndexPath) -> CollectionComponentViewModelLifecycleProtocol? {
        viewModelProvider(indexPath) as? CollectionComponentViewModelLifecycleProtocol
    }

    // MARK: - Message forwarding

    nonisolated override func responds(to aSelector: Selector!) -> Bool {
        return MainActor.assumeIsolated {
            let cls = CollectionViewDelegate.self
            if cls.flowLayoutDelegateSelectors.contains(aSelector) {
                if aSelector == cls.sizeSelector {
                    return true
                }
                return self.flowLayoutDelegate?.responds(to: aSelector) ?? false
            }

            if cls.scrollViewDelegateSelectors.contains(aSelector) {
                return self.scrollViewDelegate?.responds(to: aSelector) ?? false
            }

            if cls.selfCollectionViewDelegateSelectors.contains(aSelector) {
                return true
            }
            
            return super.responds(to: aSelector)
        }
    }
}

private extension UICollectionViewCell {
    private static var appearanceDelegateKey = 0

    // Storing a lifecycleDelegate is needed to have appearance/disappearance events in sync
    // Because batch updates make new cell appearing first and then call disappearance for old one
    // But at this point new view model is already set so wrong viewmodel receives an event

    var appearanceDelegate: CollectionComponentViewModelLifecycleProtocol? {
        get {
            objc_getAssociatedObject(
                self,
                &UICollectionViewCell.appearanceDelegateKey
            ) as? CollectionComponentViewModelLifecycleProtocol
        }
        set {
            objc_setAssociatedObject(
                self,
                &UICollectionViewCell.appearanceDelegateKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}
