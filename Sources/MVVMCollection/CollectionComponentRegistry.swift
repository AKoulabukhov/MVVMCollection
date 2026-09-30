import UIKit

@MainActor public final class CollectionComponentRegistry {
    var cellRegistrators = [CellRegistrator]()
    var cellProviders = [TypeIdentifier: ContextualCellProvider]()
    var cellSizeProviders = [TypeIdentifier: ContextualCellSizeProvider]()

    public init() { }

    public func append<Item: Hashable, ViewModel, View: UIView>(
        _ descriptor: CollectionComponentDescriptor<Item, ViewModel, View>
    ) {
        let typeIdentifier = TypeIdentifier(underlyingType: Item.self)
        let reuseIdentifier = typeIdentifier.stringValue

        cellRegistrators.append({
            $0.register(
                GenericCollectionViewCell<View>.self,
                forCellWithReuseIdentifier: reuseIdentifier
            )
        })

        let obtainViewModel: (CollectionComponentRuntime, AnySendableHashable) -> ViewModel = { runtime, item in
            /// UICollectionViewDiffableDataSource forces type erasure for multiple items type support
            let castedItem = item.wrappedValue.base as! Item

            let viewModelStorage = runtime.viewModelStorage
            if let viewModel = viewModelStorage.getViewModel(for: item) as? ViewModel {
                return viewModel
            } else {
                let viewModel = descriptor.makeViewModel(castedItem)
                if let reloadableViewModel = viewModel as? CollectionComponentViewModelReloadableProtocol {
                    reloadableViewModel.storeReloadToken(
                        BlockReloadToken { [weak runtime] animated in
                            guard let runtime = runtime else {
                                print("[MVVMCollection] WARNING: Attempted to reload \(item) while CollectionController already deallocated")
                                return
                            }
                            runtime.itemReloader(item, animated)
                        }
                    )
                }
                viewModelStorage.setViewModel(
                    viewModel: viewModel,
                    for: item
                )
                return viewModel
            }
        }

        cellProviders[typeIdentifier] = { runtime, item, collectionView, indexPath in
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: reuseIdentifier,
                for: indexPath
            ) as! GenericCollectionViewCell<View>
            cell.viewFactoryBlock = descriptor.makeView

            descriptor.assignViewModel(
                obtainViewModel(runtime, item),
                cell.view
            )

            return cell
        }

        if let calculateSize = descriptor.calculateSize {
            cellSizeProviders[typeIdentifier] = { runtime, item, collectionView, layout, indexPath in
                calculateSize(
                    obtainViewModel(runtime, item),
                    collectionView,
                    layout,
                    indexPath
                )
            }
        }
    }
}
