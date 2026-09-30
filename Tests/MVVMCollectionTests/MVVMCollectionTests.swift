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

    func testUpdateCompletionWaitsForAttach() {
        let controller = CollectionController(registry: CollectionComponentRegistry())
        let completion = expectation(description: "update completion")
        var wasCompleted = false

        controller.update(
            with: CollectionControllerData(),
            completion: {
                wasCompleted = true
                completion.fulfill()
            }
        )

        XCTAssertFalse(wasCompleted)
        controller.attach(to: makeCollectionView())
        wait(for: [completion], timeout: 1)
        XCTAssertTrue(wasCompleted)
    }

    func testViewModelLivesUntilDidEndDisplaying() throws {
        var viewModel: LifecycleViewModel?
        weak var weakViewModel: LifecycleViewModel?
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor(
                viewFactory: CollectionComponentInitViewFactory<UILabel>(),
                viewModelFactory: CollectionComponentBlockViewModelFactory<TestItem, LifecycleViewModel> { _ in
                    let model = LifecycleViewModel()
                    viewModel = model
                    weakViewModel = model
                    return model
                },
                viewModelAssigner: CollectionComponentBlockViewModelAssigner<LifecycleViewModel, UILabel> { _, _ in }
            )
        )
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        let indexPath = IndexPath(item: 0, section: 0)
        controller.attach(to: collectionView)
        controller.update(with: CollectionControllerData(items: [TestItem(id: 1)]))
        let cell = try XCTUnwrap(
            collectionView.dataSource?.collectionView(
                collectionView,
                cellForItemAt: indexPath
            )
        )
        collectionView.delegate?.collectionView?(
            collectionView,
            willDisplay: cell,
            forItemAt: indexPath
        )

        XCTAssertNotNil(viewModel)
        viewModel = nil
        controller.update(with: CollectionControllerData(items: []))

        XCTAssertNotNil(weakViewModel)
        collectionView.delegate?.collectionView?(
            collectionView,
            didEndDisplaying: cell,
            forItemAt: indexPath
        )
        XCTAssertNil(weakViewModel)
    }

    func testTypeErasedIdentifiersKeepDynamicTypeIdentity() {
        let integer = CollectionIdentifier(AnyHashable(Int(1)))
        let byte = CollectionIdentifier(AnyHashable(UInt8(1)))

        XCTAssertNotEqual(integer, byte)
    }

    func testSizeCacheCanBeBoundedAndInvalidated() throws {
        let assignmentCounter = Counter()
        let viewFactory = CollectionComponentInitViewFactory<UILabel>()
        let assigner = CollectionComponentBlockViewModelAssigner<SizingViewModel, UILabel> { viewModel, label in
            assignmentCounter.value += 1
            label.text = String(repeating: "x", count: viewModel.contentHash)
        }
        let calculator = CollectionComponentAutolayoutSizeCalculator(
            viewFactory: viewFactory,
            viewModelAssigner: assigner,
            maximumCachedSizeCount: 1
        )
        let collectionView = makeCollectionView()
        let layout = try XCTUnwrap(collectionView.collectionViewLayout as? UICollectionViewFlowLayout)
        let indexPath = IndexPath(item: 0, section: 0)

        _ = calculator.calculateSize(
            for: SizingViewModel(contentHash: 1),
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )
        _ = calculator.calculateSize(
            for: SizingViewModel(contentHash: 1),
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )
        XCTAssertEqual(assignmentCounter.value, 1)

        _ = calculator.calculateSize(
            for: SizingViewModel(contentHash: 2),
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )
        _ = calculator.calculateSize(
            for: SizingViewModel(contentHash: 1),
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )
        XCTAssertEqual(assignmentCounter.value, 3)

        calculator.invalidateCache()
        _ = calculator.calculateSize(
            for: SizingViewModel(contentHash: 1),
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )
        XCTAssertEqual(assignmentCounter.value, 4)
    }

    func testDescriptorCanBeConfiguredWithClosures() throws {
        let descriptor = CollectionComponentDescriptor<TestItem, String, UILabel>(
            makeView: UILabel.init,
            makeViewModel: { "Item \($0.id)" },
            assignViewModel: { viewModel, label in
                label.text = viewModel
            }
        )
        let registry = CollectionComponentRegistry()
        registry.append(descriptor)
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        controller.attach(to: collectionView)
        controller.update(with: CollectionControllerData(items: [TestItem(id: 7)]))

        let cell = try XCTUnwrap(
            collectionView.dataSource?.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: 0, section: 0)
            ) as? GenericCollectionViewCell<UILabel>
        )

        XCTAssertEqual(cell.view.text, "Item 7")
    }

    func testDescriptorAddedAfterAttachIsRegisteredOnUpdate() throws {
        let registry = CollectionComponentRegistry()
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        controller.attach(to: collectionView)

        registry.append(
            CollectionComponentDescriptor<TestItem, TestItem, UILabel>(
                makeView: UILabel.init,
                makeViewModel: { $0 },
                assignViewModel: { item, label in
                    label.text = "Late item \(item.id)"
                }
            )
        )
        controller.update(with: CollectionControllerData(items: [TestItem(id: 9)]))

        let cell = try XCTUnwrap(
            collectionView.dataSource?.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: 0, section: 0)
            ) as? GenericCollectionViewCell<UILabel>
        )
        XCTAssertEqual(cell.view.text, "Late item 9")
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

private final class LifecycleViewModel: CollectionComponentViewModelLifecycleProtocol { }

private struct SizingViewModel: CollectionComponentViewModelHashableContentProtocol {
    let contentHash: Int
}

private final class Counter {
    var value = 0
}
