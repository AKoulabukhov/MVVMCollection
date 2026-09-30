import Foundation

@MainActor
protocol ViewModelStorageProtocol: AnyObject {
    func setViewModel(
        viewModel: Any,
        for item: AnyHashable
    )
    func getViewModel(
        for item: AnyHashable
    ) -> Any?
    func removeUnusedViewModels(
        for data: CollectionControllerData
    )
}

@MainActor
final class ViewModelStorage: ViewModelStorageProtocol {

    private var storage = [CollectionIdentifier: Any]()

    func setViewModel(
        viewModel: Any,
        for item: AnyHashable
    ) {
        storage[CollectionIdentifier(item)] = viewModel
    }

    func getViewModel(
        for item: AnyHashable
    ) -> Any? {
        storage[CollectionIdentifier(item)]
    }

    func removeUnusedViewModels(
        for data: CollectionControllerData
    ) {
        let newItems = Set(data.snapshot.itemIdentifiers)
        let oldItems = Set(storage.keys)
        let removedItems = oldItems.subtracting(newItems)
        removedItems.forEach {
            storage[$0] = nil
        }
    }
}
