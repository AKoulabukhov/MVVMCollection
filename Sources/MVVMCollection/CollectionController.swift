import UIKit

public protocol CollectionControllerProtocol: AnyObject {
    var scrollViewDelegate: UIScrollViewDelegate? { get set }
    var flowLayoutDelegate: UICollectionViewDelegateFlowLayout? { get set }
    var supplementaryViewProvider: SupplementaryViewProvider? { get set }

    func attach(to collectionView: UICollectionView)
    func detach()
    func update(
        with data: CollectionControllerData,
        animated: Bool,
        completion: (() -> Void)?
    )
}

extension CollectionControllerProtocol {
    public func update(
        with data: CollectionControllerData,
        animated: Bool = false,
        completion: (() -> Void)? = nil
    ) {
        update(
            with: data,
            animated: animated,
            completion: completion
        )
    }
}

public final class CollectionController: CollectionControllerProtocol {
    private let registry: CollectionComponentRegistry
    private let viewModelStorage = ViewModelStorage()
    private lazy var delegate = makeDelegate()

    private weak var collectionView: UICollectionView?
    private var dataSource: DataSource?
    private var data: CollectionControllerData?

    public init(
        registry: CollectionComponentRegistry
    ) {
        self.registry = registry
        registry.viewModelStorage = viewModelStorage
        registry.itemReloader = makeItemReloader()
    }

    // MARK: - CollectionControllerProtocol

    public var scrollViewDelegate: UIScrollViewDelegate? {
        get { delegate.scrollViewDelegate }
        set { delegate.scrollViewDelegate = newValue }
    }

    public var flowLayoutDelegate: UICollectionViewDelegateFlowLayout? {
        get { delegate.flowLayoutDelegate }
        set { delegate.flowLayoutDelegate = newValue }
    }

    public var supplementaryViewProvider: SupplementaryViewProvider? {
        didSet { dataSource?.supplementaryViewProvider = supplementaryViewProvider }
    }

    public func attach(to collectionView: UICollectionView) {
        onAttach(to: collectionView)
    }

    public func detach() {
        onDetach()
    }

    public func update(
        with data: CollectionControllerData,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        onUpdate(
            with: data,
            animated: animated,
            completion: completion
        )
    }

    // MARK: - Private

    private func onAttach(to collectionView: UICollectionView) {
        if let oldCollectionView = self.collectionView {
            oldCollectionView.dataSource = nil
            oldCollectionView.delegate = nil
        }

        self.collectionView = collectionView
        registerCells(in: collectionView)
        updateDataSource(with: collectionView)
        collectionView.delegate = delegate
        applyDataSnapshot()
    }

    private func onDetach() {
        dataSource = nil
        collectionView?.dataSource = nil
        collectionView?.delegate = nil
        collectionView = nil
    }

    private func onUpdate(
        with newData: CollectionControllerData,
        animated: Bool,
        completion: (() -> Void)?
    ) {
        data = newData
        dataSource?.apply(
            newData.snapshot,
            animatingDifferences: animated,
            completion: completion
        )
        viewModelStorage.removeUnusedViewModels(for: newData)
    }

    private func updateDataSource(
        with collectionView: UICollectionView
    ) {
        let dataSource = DataSource(
            collectionView: collectionView,
            cellProvider: makeCellProvider()
        )
        dataSource.supplementaryViewProvider = supplementaryViewProvider
        self.dataSource = dataSource
        collectionView.dataSource = dataSource
    }

    private func applyDataSnapshot() {
        guard let dataSource = dataSource, let data = data else { return }
        dataSource.apply(data.snapshot)
    }

    private func registerCells(in collectionView: UICollectionView) {
        registry.cellRegistrators.forEach { registrationBlock in
            registrationBlock(collectionView)
        }
    }

    private func makeDelegate() -> CollectionViewDelegate {
        CollectionViewDelegate(
            viewModelProvider: { [weak self] indexPath in
                self?.performWithItem(
                    at: indexPath,
                    block: { strongSelf, item in
                        strongSelf.viewModelStorage.getViewModel(
                            for: item
                        )
                    }
                )
            },
            sizeProvider: { [weak self] collectionView, layout, indexPath in
                self?.performWithItem(
                    at: indexPath,
                    block: { strongSelf, item in
                        strongSelf.registry.cellSizeProviders[TypeIdentifier(item)]?(
                            item,
                            collectionView,
                            layout,
                            indexPath
                        )
                    }
                )
            }
        )
    }

    private func performWithItem<Result>(
        at indexPath: IndexPath,
        block: (CollectionController, AnyHashable) -> Result?
    ) -> Result? {
        guard let item = self.dataSource?.itemIdentifier(for: indexPath) else { return nil }
        return block(self, item)
    }

    private func makeItemReloader() -> ItemReloader {
        { [weak self] item, animated in
            guard let dataSource = self?.dataSource else { return }
            var snapshot = dataSource.snapshot()
            if #available(iOS 15.0, *) {
                snapshot.reconfigureItems([item])
            } else {
                snapshot.reloadItems([item])
            }
            dataSource.apply(
                snapshot,
                animatingDifferences: animated
            )
        }
    }

    private func makeCellProvider() -> DataSource.CellProvider {
        { [registry] collectionView, indexPath, item in
            let typeIdentifier = TypeIdentifier(item)
            guard let cellProvider = registry.cellProviders[typeIdentifier] else {
                let errorMessage = "No descriptor found for \(typeIdentifier.stringValue)"
                assertionFailure(errorMessage)
                return collectionView.obtainErrorCell(
                    with: errorMessage,
                    for: indexPath
                )
            }
            return cellProvider(
                item,
                collectionView,
                indexPath
            )
        }
    }
}
