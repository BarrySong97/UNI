# Flureadium Platform Interface

A common platform interface for the [flureadium](https://pub.dev/packages/flureadium) plugin.

This interface allows platform-specific implementations of the Flureadium plugin, as well as the plugin itself, to ensure they are implementing the same interface.

## Usage

To implement a new platform-specific implementation of `flureadium`, extend [`FlureadiumPlatform`](lib/flureadium_platform_interface.dart) with an implementation that performs the platform-specific behavior.

This package is endorsed and used by the `flureadium` package. It should not be used directly by app developers.

## Note on breaking changes

Strongly prefer non-breaking changes (such as adding a method to the interface) over breaking changes for this package.

See https://flutter.dev/go/platform-interface-breaking-changes for a discussion on why a less-clean interface is preferable to a breaking change.

## License

LGPL v3 -- see [LICENSE](LICENSE) for details.
