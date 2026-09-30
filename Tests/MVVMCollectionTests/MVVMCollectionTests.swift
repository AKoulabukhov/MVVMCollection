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

    func testViewModelIsReusedUntilItsItemIsRemoved() {
        var creationCount = 0
        weak var storedViewModel: StoredViewModel?
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor<TestItem, StoredViewModel, UILabel>(
                makeView: UILabel.init,
                makeViewModel: { _ in
                    creationCount += 1
                    let viewModel = StoredViewModel()
                    storedViewModel = viewModel
                    return viewModel
                },
                assignViewModel: { _, _ in }
            )
        )
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        let data = CollectionControllerData(items: [TestItem(id: 1)])
        let indexPath = IndexPath(item: 0, section: 0)
        controller.attach(to: collectionView)
        controller.update(with: data)

        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )
        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )
        controller.update(with: data)
        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )

        XCTAssertEqual(creationCount, 1)
        XCTAssertNotNil(storedViewModel)

        controller.update(with: CollectionControllerData(items: []))
        XCTAssertNil(storedViewModel)

        controller.update(with: data)
        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )
        XCTAssertEqual(creationCount, 2)
        XCTAssertNotNil(storedViewModel)
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

    func testPendingUpdatesApplyLatestDataAndCompleteInOrder() throws {
        let controller = CollectionController(registry: CollectionComponentRegistry())
        let firstCompletion = expectation(description: "first update completion")
        let secondCompletion = expectation(description: "second update completion")
        var completionOrder = [Int]()

        controller.update(
            with: CollectionControllerData(items: [TestItem(id: 1)]),
            completion: {
                completionOrder.append(1)
                firstCompletion.fulfill()
            }
        )
        controller.update(
            with: CollectionControllerData(items: [TestItem(id: 2), TestItem(id: 3)]),
            completion: {
                completionOrder.append(2)
                secondCompletion.fulfill()
            }
        )

        let collectionView = makeCollectionView()
        controller.attach(to: collectionView)
        wait(for: [firstCompletion, secondCompletion], timeout: 1)

        let dataSource = try XCTUnwrap(collectionView.dataSource as? DataSource)
        XCTAssertEqual(completionOrder, [1, 2])
        XCTAssertEqual(
            dataSource.snapshot().itemIdentifiers.map(\.base),
            [AnyHashable(TestItem(id: 2)), AnyHashable(TestItem(id: 3))]
        )
    }

    func testAttachingToAnotherCollectionViewDetachesThePreviousOne() throws {
        let controller = CollectionController(registry: CollectionComponentRegistry())
        let firstCollectionView = makeCollectionView()
        let secondCollectionView = makeCollectionView()
        controller.attach(to: firstCollectionView)
        controller.update(with: CollectionControllerData(items: [TestItem(id: 1)]))

        controller.attach(to: secondCollectionView)

        XCTAssertNil(firstCollectionView.dataSource)
        XCTAssertNil(firstCollectionView.delegate)
        XCTAssertNotNil(secondCollectionView.delegate)
        let dataSource = try XCTUnwrap(secondCollectionView.dataSource as? DataSource)
        XCTAssertEqual(
            dataSource.snapshot().itemIdentifiers.map(\.base),
            [AnyHashable(TestItem(id: 1))]
        )
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

    func testLifecycleViewModelReceivesInteractionEvents() throws {
        var viewModel: RecordingLifecycleViewModel?
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor<TestItem, RecordingLifecycleViewModel, UILabel>(
                makeView: UILabel.init,
                makeViewModel: { _ in
                    let model = RecordingLifecycleViewModel()
                    viewModel = model
                    return model
                },
                assignViewModel: { _, _ in }
            )
        )
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        let indexPath = IndexPath(item: 0, section: 0)
        controller.attach(to: collectionView)
        controller.update(with: CollectionControllerData(items: [TestItem(id: 1)]))
        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )
        let delegate = try XCTUnwrap(collectionView.delegate)

        XCTAssertFalse(
            delegate.collectionView?(
                collectionView,
                shouldHighlightItemAt: indexPath
            ) ?? true
        )
        delegate.collectionView?(
            collectionView,
            didHighlightItemAt: indexPath
        )
        delegate.collectionView?(
            collectionView,
            didUnhighlightItemAt: indexPath
        )
        XCTAssertFalse(
            delegate.collectionView?(
                collectionView,
                shouldSelectItemAt: indexPath
            ) ?? true
        )
        delegate.collectionView?(
            collectionView,
            didSelectItemAt: indexPath
        )
        XCTAssertFalse(
            delegate.collectionView?(
                collectionView,
                shouldDeselectItemAt: indexPath
            ) ?? true
        )
        delegate.collectionView?(
            collectionView,
            didDeselectItemAt: indexPath
        )

        XCTAssertEqual(
            viewModel?.events,
            [
                "shouldHighlight",
                "didHighlight",
                "didUnhighlight",
                "shouldSelect",
                "didSelect",
                "shouldDeselect",
                "didDeselect",
            ]
        )
    }

    func testExternalDelegatesAreAdvertisedAndForwarded() throws {
        let controller = CollectionController(registry: CollectionComponentRegistry())
        let collectionView = makeCollectionView()
        controller.attach(to: collectionView)
        let delegate = try XCTUnwrap(collectionView.delegate as? CollectionViewDelegate)
        let scrollSelector = #selector(
            UIScrollViewDelegate.scrollViewDidScroll(_:)
        )
        let sizeSelector = #selector(
            UICollectionViewDelegateFlowLayout.collectionView(_:layout:sizeForItemAt:)
        )

        XCTAssertFalse(delegate.responds(to: scrollSelector))
        XCTAssertTrue(delegate.responds(to: sizeSelector))

        let scrollViewDelegate = ScrollViewDelegateSpy()
        let flowLayoutDelegate = FlowLayoutDelegateSpy(
            size: CGSize(width: 23, height: 29)
        )
        controller.scrollViewDelegate = scrollViewDelegate
        controller.flowLayoutDelegate = flowLayoutDelegate

        XCTAssertTrue(delegate.responds(to: scrollSelector))
        delegate.scrollViewDidScroll(collectionView)
        XCTAssertEqual(scrollViewDelegate.didScrollCount, 1)

        let size = delegate.collectionView(
            collectionView,
            layout: collectionView.collectionViewLayout,
            sizeForItemAt: IndexPath(item: 0, section: 0)
        )
        XCTAssertEqual(size, flowLayoutDelegate.size)
        XCTAssertEqual(flowLayoutDelegate.sizeRequestCount, 1)
    }

    func testTypeErasedIdentifiersKeepDynamicTypeIdentity() {
        let integer = CollectionIdentifier(AnyHashable(Int(1)))
        let byte = CollectionIdentifier(AnyHashable(UInt8(1)))

        XCTAssertNotEqual(integer, byte)
    }

    func testViewModelStorageKeepsDynamicTypeIdentity() throws {
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor<Int, String, UILabel>(
                makeView: UILabel.init,
                makeViewModel: { "Int \($0)" },
                assignViewModel: { viewModel, label in
                    label.text = viewModel
                }
            )
        )
        registry.append(
            CollectionComponentDescriptor<UInt8, String, UILabel>(
                makeView: UILabel.init,
                makeViewModel: { "UInt8 \($0)" },
                assignViewModel: { viewModel, label in
                    label.text = viewModel
                }
            )
        )
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        controller.attach(to: collectionView)
        controller.update(with: CollectionControllerData(items: [Int(1), UInt8(1)]))

        let integerCell = try XCTUnwrap(
            collectionView.dataSource?.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: 0, section: 0)
            ) as? GenericCollectionViewCell<UILabel>
        )
        let byteCell = try XCTUnwrap(
            collectionView.dataSource?.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: 1, section: 0)
            ) as? GenericCollectionViewCell<UILabel>
        )

        XCTAssertEqual(integerCell.view.text, "Int 1")
        XCTAssertEqual(byteCell.view.text, "UInt8 1")
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

    func testSizeCacheEvictsLeastRecentlyUsedEntry() throws {
        let assignmentCounter = Counter()
        let viewFactory = CollectionComponentInitViewFactory<UILabel>()
        let assigner = CollectionComponentBlockViewModelAssigner<SizingViewModel, UILabel> { _, _ in
            assignmentCounter.value += 1
        }
        let calculator = CollectionComponentAutolayoutSizeCalculator(
            viewFactory: viewFactory,
            viewModelAssigner: assigner,
            maximumCachedSizeCount: 2
        )
        let collectionView = makeCollectionView()
        let layout = try XCTUnwrap(collectionView.collectionViewLayout as? UICollectionViewFlowLayout)
        let indexPath = IndexPath(item: 0, section: 0)

        func calculate(_ contentHash: Int) {
            _ = calculator.calculateSize(
                for: SizingViewModel(contentHash: contentHash),
                collectionView: collectionView,
                layout: layout,
                indexPath: indexPath
            )
        }

        calculate(1)
        calculate(2)
        calculate(1)
        calculate(3)
        calculate(1)
        XCTAssertEqual(assignmentCounter.value, 3)

        calculate(2)
        XCTAssertEqual(assignmentCounter.value, 4)
    }

    func testSizeCacheSeparatesDifferentCollectionWidths() throws {
        let assignmentCounter = Counter()
        let viewFactory = CollectionComponentInitViewFactory<UILabel>()
        let assigner = CollectionComponentBlockViewModelAssigner<SizingViewModel, UILabel> { _, _ in
            assignmentCounter.value += 1
        }
        let calculator = CollectionComponentAutolayoutSizeCalculator(
            viewFactory: viewFactory,
            viewModelAssigner: assigner
        )
        let collectionView = makeCollectionView()
        let layout = try XCTUnwrap(collectionView.collectionViewLayout as? UICollectionViewFlowLayout)
        let indexPath = IndexPath(item: 0, section: 0)
        let viewModel = SizingViewModel(contentHash: 1)

        _ = calculator.calculateSize(
            for: viewModel,
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )
        collectionView.bounds.size.width = 200
        _ = calculator.calculateSize(
            for: viewModel,
            collectionView: collectionView,
            layout: layout,
            indexPath: indexPath
        )

        XCTAssertEqual(assignmentCounter.value, 2)
    }

    func testSizingAndCellBindingShareViewModel() throws {
        var creationCount = 0
        var sizingViewModel: StoredViewModel?
        var assignedViewModel: StoredViewModel?
        let expectedSize = CGSize(width: 37, height: 41)
        let registry = CollectionComponentRegistry()
        registry.append(
            CollectionComponentDescriptor<TestItem, StoredViewModel, UILabel>(
                makeView: UILabel.init,
                makeViewModel: { _ in
                    creationCount += 1
                    return StoredViewModel()
                },
                assignViewModel: { viewModel, _ in
                    assignedViewModel = viewModel
                },
                calculateSize: { viewModel, _, _, _ in
                    sizingViewModel = viewModel
                    return expectedSize
                }
            )
        )
        let controller = CollectionController(registry: registry)
        let collectionView = makeCollectionView()
        let layout = try XCTUnwrap(collectionView.collectionViewLayout as? UICollectionViewFlowLayout)
        let indexPath = IndexPath(item: 0, section: 0)
        controller.attach(to: collectionView)
        controller.update(with: CollectionControllerData(items: [TestItem(id: 1)]))

        let delegate = try XCTUnwrap(
            collectionView.delegate as? UICollectionViewDelegateFlowLayout
        )
        let size = try XCTUnwrap(
            delegate.collectionView?(
                collectionView,
                layout: layout,
                sizeForItemAt: indexPath
            )
        )
        _ = collectionView.dataSource?.collectionView(
            collectionView,
            cellForItemAt: indexPath
        )

        XCTAssertEqual(size, expectedSize)
        XCTAssertEqual(creationCount, 1)
        XCTAssertTrue(sizingViewModel === assignedViewModel)
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

    func testDataCanBeCreatedWithCorrectlyNamedSectionProtocol() {
        let data = CollectionControllerData(
            sections: [
                TestSection(id: 1, items: [TestItem(id: 1)]),
                TestSection(id: 2, items: [TestItem(id: 2), TestItem(id: 3)]),
            ]
        )

        XCTAssertEqual(data.snapshot.numberOfSections, 2)
        XCTAssertEqual(data.snapshot.numberOfItems, 3)
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

private struct TestSection: CollectionControllerDataSectionProtocol {
    let id: Int
    let items: [AnyHashable]
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

private final class RecordingLifecycleViewModel: CollectionComponentViewModelLifecycleProtocol {
    private(set) var events = [String]()

    func shouldHighlight(indexPath: IndexPath) -> Bool {
        events.append("shouldHighlight")
        return false
    }

    func didHighlight(indexPath: IndexPath) {
        events.append("didHighlight")
    }

    func didUnhighlight(indexPath: IndexPath) {
        events.append("didUnhighlight")
    }

    func shouldSelect(indexPath: IndexPath) -> Bool {
        events.append("shouldSelect")
        return false
    }

    func didSelect(indexPath: IndexPath) {
        events.append("didSelect")
    }

    func shouldDeselect(indexPath: IndexPath) -> Bool {
        events.append("shouldDeselect")
        return false
    }

    func didDeselect(indexPath: IndexPath) {
        events.append("didDeselect")
    }
}

private final class StoredViewModel { }

private final class ScrollViewDelegateSpy: NSObject, UIScrollViewDelegate {
    private(set) var didScrollCount = 0

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        didScrollCount += 1
    }
}

private final class FlowLayoutDelegateSpy: NSObject, UICollectionViewDelegateFlowLayout {
    let size: CGSize
    private(set) var sizeRequestCount = 0

    init(size: CGSize) {
        self.size = size
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        sizeRequestCount += 1
        return size
    }
}

private struct SizingViewModel: CollectionComponentViewModelHashableContentProtocol {
    let contentHash: Int
}

private final class Counter {
    var value = 0
}
