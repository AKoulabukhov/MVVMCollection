import UIKit

@MainActor
public struct CollectionComponentDescriptor<Item: Hashable, ViewModel, View: UIView> {
    public typealias ViewFactoryBlock = () -> View
    public typealias ViewModelFactoryBlock = (Item) -> ViewModel
    public typealias ViewModelAssignBlock = (ViewModel, View) -> Void
    public typealias ViewSizeCalculatorBlock = (
        ViewModel,
        UICollectionView,
        UICollectionViewLayout,
        IndexPath
    ) -> CGSize

    let makeView: ViewFactoryBlock
    let makeViewModel: ViewModelFactoryBlock
    let assignViewModel: ViewModelAssignBlock
    let calculateSize: ViewSizeCalculatorBlock?

    public init(
        makeView: @escaping ViewFactoryBlock,
        makeViewModel: @escaping ViewModelFactoryBlock,
        assignViewModel: @escaping ViewModelAssignBlock,
        calculateSize: ViewSizeCalculatorBlock? = nil
    ) {
        self.makeView = makeView
        self.makeViewModel = makeViewModel
        self.assignViewModel = assignViewModel
        self.calculateSize = calculateSize
    }

    public init<
        ViewFactory: CollectionComponentViewFactoryProtocol,
        ViewModelFactory: CollectionComponentViewModelFactoryProtocol,
        ViewModelAssigner: CollectionComponentViewModelAssignerProtocol
    >(
        viewFactory: ViewFactory,
        viewModelFactory: ViewModelFactory,
        viewModelAssigner: ViewModelAssigner
    ) where
        ViewFactory.View == View,
        ViewModelFactory.Item == Item,
        ViewModelFactory.ViewModel == ViewModel,
        ViewModelAssigner.ViewModel == ViewModel,
        ViewModelAssigner.View == View
    {
        self.init(
            makeView: viewFactory.makeView,
            makeViewModel: viewModelFactory.makeViewModel,
            assignViewModel: viewModelAssigner.assignViewModel
        )
    }
    
    public init<
        ViewFactory: CollectionComponentViewFactoryProtocol,
        ViewModelFactory: CollectionComponentViewModelFactoryProtocol,
        ViewModelAssigner: CollectionComponentViewModelAssignerProtocol,
        ViewSizeCalculator: CollectionComponentViewSizeCalculatorProtocol
    >(
        viewFactory: ViewFactory,
        viewModelFactory: ViewModelFactory,
        viewModelAssigner: ViewModelAssigner,
        viewSizeCalculator: ViewSizeCalculator
    ) where
        ViewFactory.View == View,
        ViewModelFactory.Item == Item,
        ViewModelFactory.ViewModel == ViewModel,
        ViewModelAssigner.ViewModel == ViewModel,
        ViewModelAssigner.View == View,
        ViewSizeCalculator.ViewModel == ViewModel
    {
        self.init(
            makeView: viewFactory.makeView,
            makeViewModel: viewModelFactory.makeViewModel,
            assignViewModel: viewModelAssigner.assignViewModel,
            calculateSize: viewSizeCalculator.calculateSize
        )
    }
}
