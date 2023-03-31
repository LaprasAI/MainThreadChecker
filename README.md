# MainThreadChecker

MainThreadChecker is a utility for debugging to detect main thread block or lags.

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Example](#example)
- [How does it work](#how&#32does&#32it&#32work)
- [Credits](#credits)

## Requirements

Though this library is compatible with earlier versions of iOS and Swift, but the recommand environment is as below.
- iOS 11.0+
- Xcode 14.0+
- Swift 5.0+

## Installation

### Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager/) is a tool for managing the distribution of Swift code. It’s integrated with the Swift build system to automate the process of downloading, compiling, and linking dependencies.

To integrate MainThreadChecker into your Xcode project using Swift Package Manager, add it to the dependencies value of your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/LaprasAI/MainThreadChecker", .upToNextMajor(from: "0.0.1"))
]
```

### CocoaPods

MainThreadChecker does not provide cocoapods support for now, however you can download the project file or just copy and paste the code and create the pod of your own.

### Manually

Just drag MainThreadChecker.swift into your project.

---

## Usage

### Quick Start

```swift
import MainThreadChecker

MainThreadChecker.shared.start(checking: 1.0, in: .parentMode) {
    fatalError("Detected main thread block!")
}
```

## Example

See demo app - MainThreadCheckerDemo

## How does it work
It synchronizes current activity of the main run loop out using a semaphore before reaching a pre-set threshold time.

While the semaphore's time of waiting meets the threshold time, no block or lags happens. If not, the checker will judge the last activity of the main run loop. For activity of .beforeWaiting, the main thread is currently healthy, but for activities of .beforeSources and .afterWaiting, the checker can assert that the main thread is now running heavy jobs so that a block or lag happens.

Notice:
- When the app goes to the background, its main thread sleeps and will unexpectedly trigger the time's up alarm. In that case, MainThreadChecker sleeps too and will not trigger an alarm before the app comes back to the foreground.
- By default, the checker is running in common mode which means it will not check under development environment such as launching from Xcode because any break points which suspend the process may also unexpectedly trigger the checker's alarm. However, you can start checking in parent mode programmatically which means it will ignore whether there's any debugger attached and start checking anyway.

## Credits

- Created by Li Yuyang (lyy9610@outlook.com)


