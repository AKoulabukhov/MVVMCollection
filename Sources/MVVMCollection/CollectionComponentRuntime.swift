import Foundation

@MainActor
final class CollectionComponentRuntime {
    let viewModelStorage: ViewModelStorageProtocol
    let itemReloader: ItemReloader

    init(
        itemReloader: @escaping ItemReloader
    ) {
        self.viewModelStorage = ViewModelStorage()
        self.itemReloader = itemReloader
    }
}
