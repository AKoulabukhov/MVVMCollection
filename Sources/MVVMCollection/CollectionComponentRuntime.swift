import Foundation

final class CollectionComponentRuntime {
    let viewModelStorage: ViewModelStorageProtocol
    let itemReloader: ItemReloader

    init(
        viewModelStorage: ViewModelStorageProtocol = ViewModelStorage(),
        itemReloader: @escaping ItemReloader
    ) {
        self.viewModelStorage = viewModelStorage
        self.itemReloader = itemReloader
    }
}
