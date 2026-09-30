import UIKit

public protocol CollectionConrollerDataSectionProtocol: Hashable {
    var items: [AnyHashable] { get }
}

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

    public init<Section: CollectionConrollerDataSectionProtocol>(
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
