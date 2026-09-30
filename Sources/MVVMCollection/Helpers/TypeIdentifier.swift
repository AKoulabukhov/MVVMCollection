import Foundation

struct TypeIdentifier: Hashable {
    let underlyingType: Any.Type

    var stringValue: String {
        String(reflecting: underlyingType)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(stringValue)
    }

    static func == (lhs: TypeIdentifier, rhs: TypeIdentifier) -> Bool {
        lhs.stringValue == rhs.stringValue
    }
}

extension TypeIdentifier {
    init(_ anyHashable: AnyHashable) {
        self.underlyingType = type(of: anyHashable.base)
    }
}
