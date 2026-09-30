import XCTest
import UIKit
@testable import MVVMCollection

@MainActor
final class MVVMCollectionTests: XCTestCase {
    func testReloadConvenienceUsesNonAnimatedReload() {
        let token = ReloadTokenSpy()

        token.reload()

        XCTAssertEqual(token.animatedValues, [false])
    }

    func testReloadAfterItemRemovalIsIgnored() throws {
        var viewModel: ReloadableViewModel?
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor(
                viewFactory: CollectionComponentInitViewFactory<UILabel>(),
                viewModelFactory: CollectionComponentBlockViewModelFactory<TestItem, ReloadableViewModel> { item in
                    let model = ReloadableViewModel(item: item)
                    viewModel = model
                    return model
                },
                viewModelAssigner: CollectionComponentBlockViewModelAssigner<ReloadableViewModel, UILabel> { _, _ in }
            )
        )
        let controller = CollectionController(registry: registry)
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        controller.attach(to: collectionView)
        controller.update(with: CollectionControllerData(items: [TestItem(id: 1)]))

        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: IndexPath(item: 0, section: 0)
        )
        let reloadToken = try XCTUnwrap(viewModel?.reloadToken)

        controller.update(with: CollectionControllerData(items: []))
        reloadToken.reload(animated: false)
    }
}

private final class ReloadTokenSpy: ReloadTokenProtocol {
    private(set) var animatedValues = [Bool]()

    func reload(animated: Bool) {
        animatedValues.append(animated)
    }
}

private struct TestItem: Hashable {
    let id: Int
}

private final class ReloadableViewModel: CollectionComponentViewModelReloadableProtocol {
    let item: TestItem
    private(set) var reloadToken: ReloadTokenProtocol?

    init(item: TestItem) {
        self.item = item
    }

    func storeReloadToken(_ token: ReloadTokenProtocol) {
        reloadToken = token
    }
}
