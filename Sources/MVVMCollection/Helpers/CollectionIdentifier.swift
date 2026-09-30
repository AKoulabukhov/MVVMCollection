import Foundation

/// Type-erased diffable identifier that preserves the package's heterogeneous API
/// while satisfying UIKit's Sendable constraint. Wrapped values must obey the
/// Hashable contract and remain stable while stored in a snapshot.
struct CollectionIdentifier: Hashable, @unchecked Sendable {
    let base: AnyHashable
    private let typeIdentifier: TypeIdentifier

    init(_ base: AnyHashable) {
        self.base = base
        self.typeIdentifier = TypeIdentifier(base)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(typeIdentifier)
        hasher.combine(base)
    }

    static func == (lhs: CollectionIdentifier, rhs: CollectionIdentifier) -> Bool {
        lhs.typeIdentifier == rhs.typeIdentifier && lhs.base == rhs.base
    }
}
