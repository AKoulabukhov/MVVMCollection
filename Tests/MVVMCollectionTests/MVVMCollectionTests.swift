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

    func testRegistryCanBeSharedByMultipleControllers() {
        var madeViewModels = [ReloadableViewModel]()
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor(
                viewFactory: CollectionComponentInitViewFactory<UILabel>(),
                viewModelFactory: CollectionComponentBlockViewModelFactory<TestItem, ReloadableViewModel> { item in
                    let viewModel = ReloadableViewModel(item: item)
                    madeViewModels.append(viewModel)
                    return viewModel
                },
                viewModelAssigner: CollectionComponentBlockViewModelAssigner<ReloadableViewModel, UILabel> { _, _ in }
            )
        )
        let firstController = CollectionController(registry: registry)
        let secondController = CollectionController(registry: registry)
        let firstCollectionView = makeCollectionView()
        let secondCollectionView = makeCollectionView()
        let data = CollectionControllerData(items: [TestItem(id: 1)])

        firstController.attach(to: firstCollectionView)
        secondController.attach(to: secondCollectionView)
        firstController.update(with: data)
        secondController.update(with: data)

        _ = firstCollectionView.dataSource?.collectionView(
            firstCollectionView,
            cellForItemAt: IndexPath(item: 0, section: 0)
        )
        _ = secondCollectionView.dataSource?.collectionView(
            secondCollectionView,
            cellForItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(madeViewModels.count, 2)
        XCTAssertFalse(madeViewModels[0] === madeViewModels[1])
    }

    private func makeCollectionView() -> UICollectionView {
        UICollectionView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 480),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
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
