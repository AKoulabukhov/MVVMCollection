import UIKit

typealias DataSource = UICollectionViewDiffableDataSource<AnySendableHashable, AnySendableHashable>
typealias Snapshot = NSDiffableDataSourceSnapshot<AnySendableHashable, AnySendableHashable>

typealias CellRegistrator = (
    _ collectionView: UICollectionView
) -> Void

typealias CellProvider = (
    _ item: AnySendableHashable,
    _ collectionView: UICollectionView,
    _ indexPath: IndexPath
) -> UICollectionViewCell

typealias ContextualCellProvider = (
    _ runtime: CollectionComponentRuntime,
    _ item: AnySendableHashable,
    _ collectionView: UICollectionView,
    _ indexPath: IndexPath
) -> UICollectionViewCell

typealias CellSizeProvider = (
    _ item: AnySendableHashable,
    _ collectionView: UICollectionView,
    _ layout: UICollectionViewLayout,
    _ indexPath: IndexPath
) -> CGSize

typealias ContextualCellSizeProvider = (
    _ runtime: CollectionComponentRuntime,
    _ item: AnySendableHashable,
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
    _ item: AnySendableHashable,
    _ animated: Bool
) -> Void

public typealias SupplementaryViewProvider = (
    _ collectionView: UICollectionView,
    _ elementKind: String,
    _ indexPath: IndexPath
) -> UICollectionReusableView?
