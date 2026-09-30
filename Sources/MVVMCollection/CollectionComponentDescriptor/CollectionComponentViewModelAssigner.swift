import Foundation

@MainActor
public protocol CollectionComponentViewModelAssignerProtocol {
    associatedtype ViewModel
    associatedtype View

    func assignViewModel(
        _ viewModel: ViewModel,
        to view: View
    )
}

@MainActor
public struct CollectionComponentBlockViewModelAssigner<ViewModel, View>: CollectionComponentViewModelAssignerProtocol {
    private let assignmentBlock: (ViewModel, View) -> Void

    public init(
        assignmentBlock: @escaping (ViewModel, View) -> Void
    ) {
        self.assignmentBlock = assignmentBlock
    }

    public func assignViewModel(_ viewModel: ViewModel, to view: View) {
        assignmentBlock(viewModel, view)
    }
}
