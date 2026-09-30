import UIKit

public protocol CollectionControllerDataSectionProtocol: Hashable {
    var items: [AnyHashable] { get }
}

@available(*, deprecated, renamed: "CollectionControllerDataSectionProtocol")
public typealias CollectionConrollerDataSectionProtocol = CollectionControllerDataSectionProtocol

public final class CollectionControllerData {
    public init() { }

    var snapshot = Snapshot()

    public init(items: [AnyHashable]) {
        let section = CollectionIdentifier(AnyHashable(0))
        snapshot.appendSections([section])
        snapshot.appendItems(
            items.map(CollectionIdentifier.init),
            toSection: section
        )
    }

    public init<Section: CollectionControllerDataSectionProtocol>(
        sections: [Section]
    ) {
        sections.forEach { section in
            let sectionIdentifier = CollectionIdentifier(AnyHashable(section))
            snapshot.appendSections([sectionIdentifier])
            snapshot.appendItems(
                section.items.map(CollectionIdentifier.init),
                toSection: sectionIdentifier
            )
        }
    }
}
