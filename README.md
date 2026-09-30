# MVVMCollection

`MVVMCollection` is a small UIKit package that connects heterogeneous
`UICollectionView` items to views and view models while using a diffable data
source internally.

It provides:

- type-based component registration;
- one cached view model per item identifier;
- diffable snapshot updates;
- selection and display lifecycle callbacks for view models;
- view-model initiated cell reloads;
- Auto Layout sizing for `UICollectionViewFlowLayout`;
- forwarding to external scroll and flow-layout delegates.

The package supports iOS 13, macOS Catalyst 13, and tvOS 13.

## Installation

Add this repository as a Swift Package dependency and link the
`MVVMCollection` library product to the application target.

## Basic usage

```swift
import MVVMCollection
import UIKit

struct UserItem: Hashable {
    let id: UUID
}

final class UserViewModel {
    let title: String

    init(item: UserItem) {
        title = item.id.uuidString
    }
}

let registry = CollectionComponentRegistry()

registry.append(
    CollectionComponentDescriptor<UserItem, UserViewModel, UILabel>(
        makeView: {
            let label = UILabel()
            label.numberOfLines = 0
            return label
        },
        makeViewModel: UserViewModel.init,
        assignViewModel: { viewModel, label in
            label.text = viewModel.title
        }
    )
)

let controller = CollectionController(registry: registry)
controller.attach(to: collectionView)
controller.update(
    with: CollectionControllerData(
        items: [UserItem(id: UUID())]
    ),
    animated: true
)
```

The public UIKit-facing API is isolated to `MainActor`.

## Item identity and view-model lifetime

An item is both a diffable identifier and the key used to cache its view model.
Its `Hashable` identity must remain stable while it is in a snapshot.

The view-model factory runs only when no cached view model exists for that item.
Consequently, it is best to use an immutable identifier as `Item` and keep
changing presentation state in the view model. If two values compare equal,
submitting the second value does not create or update the existing view model.

View models are removed from storage when their items leave the latest data.
A view model used by a disappearing cell is retained until its matching
`didEndDisplay` callback has been delivered.

The same registry can safely be shared by multiple collection controllers;
each controller owns an independent view-model runtime.

## Reloading from a view model

Conform a view model to `CollectionComponentViewModelReloadableProtocol` and
store the supplied token:

```swift
@MainActor
final class ReloadableViewModel: CollectionComponentViewModelReloadableProtocol {
    private var reloadToken: ReloadTokenProtocol?

    func storeReloadToken(_ token: ReloadTokenProtocol) {
        reloadToken = token
    }

    func contentDidChange() {
        reloadToken?.reload(animated: true)
    }
}
```

Reloading an item that has already left the snapshot is safely ignored.

## Lifecycle callbacks

A view model may conform to
`CollectionComponentViewModelLifecycleProtocol` to receive highlighting,
selection, and display callbacks. Every method has a default implementation.

Use `scrollViewDelegate` and `flowLayoutDelegate` on `CollectionController`
for UIKit delegate behavior that does not belong in a view model.

## Sections

For multiple sections, make the section type conform to
`CollectionControllerDataSectionProtocol`:

```swift
struct CollectionSection: CollectionControllerDataSectionProtocol {
    let id: String
    let items: [AnyHashable]
}

let data = CollectionControllerData(
    sections: [
        CollectionSection(id: "users", items: users),
    ]
)
```

The misspelled `CollectionConrollerDataSectionProtocol` remains as a deprecated
alias for source compatibility.

## Self-sizing views

`CollectionComponentAutolayoutSizeCalculator` measures a reusable prototype
view for `UICollectionViewFlowLayout`. By default, a vertical layout fills the
available width and a horizontal layout fills the available height.

When a view model conforms to
`CollectionComponentViewModelHashableContentProtocol`, calculated sizes are
cached using `contentHash`, the available dimensions, layout settings, and the
relevant trait environment. Change `contentHash` whenever size-affecting
content changes.

The cache is limited to 500 entries by default. Configure
`maximumCachedSizeCount` when creating the calculator, or call
`invalidateCache()` after an external size-affecting change that is not
represented by the cache key.

## Update behavior

Calling `update` before `attach` is supported. The latest snapshot is applied
when a collection view is attached, and pending completion blocks run after
that application finishes.

Descriptors are normally appended before attaching the controller. A descriptor
added later is registered automatically on the next `update`.

## Development

Run the package tests on an iOS Simulator:

```sh
xcodebuild \
  -scheme MVVMCollection \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  test
```

The library and tests also compile in Swift 6 language mode.
