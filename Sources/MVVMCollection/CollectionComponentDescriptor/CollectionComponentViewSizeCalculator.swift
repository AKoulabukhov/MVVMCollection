import UIKit

/// Works only with UICollectionViewFlowLayout
/// For any custom layout it will not be used
@MainActor
public protocol CollectionComponentViewSizeCalculatorProtocol {
    associatedtype ViewModel

    func calculateSize(
        for viewModel: ViewModel,
        collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        indexPath: IndexPath
    ) -> CGSize
}

private enum Constants {
    /// Set before size calculation to ensure any `layoutSubviews()` modifications applied
    static let reasonablyBigDimension: CGFloat = 10000
}

@MainActor
public final class CollectionComponentAutolayoutSizeCalculator<
    ViewModel,
    ViewFactory: CollectionComponentViewFactoryProtocol,
    ViewModelAssigner: CollectionComponentViewModelAssignerProtocol
>: CollectionComponentViewSizeCalculatorProtocol where
    ViewModelAssigner.ViewModel == ViewModel,
    ViewModelAssigner.View == ViewFactory.View
{
    private let viewFactory: ViewFactory
    private let viewModelAssigner: ViewModelAssigner
    private let minSize: CGSize
    private let fillsThroughAxis: Bool
    private let maximumCachedSizeCount: Int

    private lazy var view = viewFactory.makeView()
    private lazy var cache = [SizeCacheKey: CGSize]()
    private lazy var cacheAccessOrder = [SizeCacheKey]()

    public init(
        viewFactory: ViewFactory,
        viewModelAssigner: ViewModelAssigner,
        minSize: CGSize = .zero,
        fillsThroughAxis: Bool = true,
        maximumCachedSizeCount: Int = 500
    ) {
        precondition(maximumCachedSizeCount >= 0, "maximumCachedSizeCount must not be negative")
        self.viewFactory = viewFactory
        self.viewModelAssigner = viewModelAssigner
        self.minSize = minSize
        self.fillsThroughAxis = fillsThroughAxis
        self.maximumCachedSizeCount = maximumCachedSizeCount
    }

    public func invalidateCache() {
        cache.removeAll(keepingCapacity: true)
        cacheAccessOrder.removeAll(keepingCapacity: true)
    }
    
    public func calculateSize(
        for viewModel: ViewModel,
        collectionView: UICollectionView,
        layout: UICollectionViewLayout,
        indexPath: IndexPath
    ) -> CGSize {
        guard let layout = layout as? UICollectionViewFlowLayout else {
            assertionFailure(
                "Incorrect layout type, expected UICollectionViewFlowLayout, got \(type(of: layout))"
            )
            return .zero
        }

        let delegate = collectionView.delegate as? UICollectionViewDelegateFlowLayout

        let insets = delegate?.collectionView?(
            collectionView,
            layout: layout,
            insetForSectionAt: indexPath.section
        ) ?? layout.sectionInset

        let maxSize = CGSize(
            width: collectionView.bounds.size.width - insets.left - insets.right,
            height: collectionView.bounds.size.height - insets.top - insets.bottom
        )

        let nonScrollDirectionPriority: UILayoutPriority = fillsThroughAxis ? .required : .fittingSizeLevel

        func calculateSize() -> CGSize {
            viewModelAssigner.assignViewModel(
                viewModel,
                to: view
            )

            switch layout.scrollDirection {
            case .vertical:
                let fittingSize = CGSize(
                    width: maxSize.width,
                    height: Constants.reasonablyBigDimension
                )
                view.setSizeAndLayout(fittingSize)

                let calculatedSize = view.systemLayoutSizeFitting(
                    fittingSize,
                    withHorizontalFittingPriority: nonScrollDirectionPriority,
                    verticalFittingPriority: .fittingSizeLevel
                )

                return CGSize(
                    width: max(
                        minSize.width,
                        fillsThroughAxis ? fittingSize.width : calculatedSize.roundedWidth
                    ),
                    height: max(
                        minSize.height,
                        calculatedSize.roundedHeight
                    )
                )

            case .horizontal:
                let fittingSize = CGSize(
                    width: Constants.reasonablyBigDimension,
                    height: maxSize.height
                )
                view.setSizeAndLayout(fittingSize)

                let calculatedSize = view.systemLayoutSizeFitting(
                    fittingSize,
                    withHorizontalFittingPriority: .fittingSizeLevel,
                    verticalFittingPriority: nonScrollDirectionPriority
                )

                return CGSize(
                    width: max(
                        minSize.width,
                        calculatedSize.roundedWidth
                    ),
                    height: max(
                        minSize.height,
                        fillsThroughAxis ? fittingSize.height : calculatedSize.roundedHeight
                    )
                )

            @unknown default:
                assertionFailure("Unhandled scroll direction")
                return .zero
            }
        }

        if let hashableViewModel = viewModel as? CollectionComponentViewModelHashableContentProtocol {
            let cacheKey = SizeCacheKey(
                viewModelType: ViewModel.self,
                contentHash: hashableViewModel.contentHash,
                maxSize: maxSize,
                minSize: minSize,
                fillsThroughAxis: fillsThroughAxis,
                scrollDirection: layout.scrollDirection,
                traitCollection: collectionView.traitCollection,
                layoutDirection: collectionView.effectiveUserInterfaceLayoutDirection
            )
            if let cachedSize = cache[cacheKey] {
                markCacheKeyAsRecentlyUsed(cacheKey)
                return cachedSize
            } else {
                let size = calculateSize()
                cacheSize(size, for: cacheKey)
                return size
            }
        } else {
            return calculateSize()
        }
    }

    private func cacheSize(_ size: CGSize, for key: SizeCacheKey) {
        guard maximumCachedSizeCount > 0 else { return }

        while cache.count >= maximumCachedSizeCount, let oldestKey = cacheAccessOrder.first {
            cache[oldestKey] = nil
            cacheAccessOrder.removeFirst()
        }
        cache[key] = size
        cacheAccessOrder.append(key)
    }

    private func markCacheKeyAsRecentlyUsed(_ key: SizeCacheKey) {
        guard let index = cacheAccessOrder.firstIndex(of: key) else { return }
        cacheAccessOrder.remove(at: index)
        cacheAccessOrder.append(key)
    }
}

/// Gathers all parameters affecting final calculated size
private struct SizeCacheKey: Hashable {
    let viewModelType: String
    let contentHash: Int
    let maxSizeWidth: CGFloat
    let maxSizeHeight: CGFloat
    let minSizeWidth: CGFloat
    let minSizeHeight: CGFloat
    let fillsThroughAxis: Bool
    let scrollDirection: UICollectionView.ScrollDirection.RawValue
    let preferredContentSizeCategory: String
    let horizontalSizeClass: UIUserInterfaceSizeClass.RawValue
    let verticalSizeClass: UIUserInterfaceSizeClass.RawValue
    let displayScale: CGFloat
    let layoutDirection: UIUserInterfaceLayoutDirection.RawValue

    init(
        viewModelType: Any.Type,
        contentHash: Int,
        maxSize: CGSize,
        minSize: CGSize,
        fillsThroughAxis: Bool,
        scrollDirection: UICollectionView.ScrollDirection,
        traitCollection: UITraitCollection,
        layoutDirection: UIUserInterfaceLayoutDirection
    ) {
        self.viewModelType = String(reflecting: viewModelType)
        self.contentHash = contentHash
        self.maxSizeWidth = maxSize.width
        self.maxSizeHeight = maxSize.height
        self.minSizeWidth = minSize.width
        self.minSizeHeight = minSize.height
        self.fillsThroughAxis = fillsThroughAxis
        self.scrollDirection = scrollDirection.rawValue
        self.preferredContentSizeCategory = traitCollection.preferredContentSizeCategory.rawValue
        self.horizontalSizeClass = traitCollection.horizontalSizeClass.rawValue
        self.verticalSizeClass = traitCollection.verticalSizeClass.rawValue
        self.displayScale = traitCollection.displayScale
        self.layoutDirection = layoutDirection.rawValue
    }
}

private extension UIView {
    func setSizeAndLayout(_ size: CGSize) {
        frame.size = size
        setNeedsLayout()
        layoutIfNeeded()
    }
}

private extension CGSize {
    var roundedHeight: CGFloat {
        height.rounded(.awayFromZero)
    }
    var roundedWidth: CGFloat {
        width.rounded(.awayFromZero)
    }
}
