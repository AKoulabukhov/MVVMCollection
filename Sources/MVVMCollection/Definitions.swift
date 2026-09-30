import UIKit

typealias DataSource = UICollectionViewDiffableDataSource<CollectionIdentifier, CollectionIdentifier>
typealias Snapshot = NSDiffableDataSourceSnapshot<CollectionIdentifier, CollectionIdentifier>

typealias CellRegistrator = (
    _ collectionView: UICollectionView
) -> Void

typealias CellProvider = (
    _ item: AnyHashable,
    _ collectionView: UICollectionView,
    _ indexPath: IndexPath
) -> UICollectionViewCell

typealias ContextualCellProvider = (
    _ runtime: CollectionComponentRuntime,
    _ item: AnyHashable,
    _ collectionView: UICollectionView,
    _ indexPath: IndexPath
) -> UICollectionViewCell

typealias CellSizeProvider = (
    _ item: AnyHashable,
    _ collectionView: UICollectionView,
    _ layout: UICollectionViewLayout,
    _ indexPath: IndexPath
) -> CGSize

typealias ContextualCellSizeProvider = (
    _ runtime: CollectionComponentRuntime,
    _ item: AnyHashable,
    _ collectionView: UICollectionView,
    _ layout: UICollectionViewLayout,
    _ indexPath: IndexPath
) -> CGSize

typealias ViewModelAtIndexPathProvider = (
    _ indexPath: IndexPath
) -> Any?

typealias CellSizeAtIndexPathProvider = (
    _ collectionView: UICollectionView,
    _ layout: UICollectionViewLayout,
    _ indexPath: IndexPath
) -> CGSize?

typealias ItemReloader = (
    _ item: AnyHashable,
    _ animated: Bool
) -> Void

public typealias SupplementaryViewProvider = (
    _ collectionView: UICollectionView,
    _ elementKind: String,
    _ indexPath: IndexPath
) -> UICollectionReusableView?
