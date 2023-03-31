import UIKit


/// Checking lag or block on main thread.
public final class MainThreadChecker {
    
    private enum RelativeState {
        case common, toBackground, toForeground
    }
    public enum CheckingMode {
        case commonMode, parentMode
    }
    
    public static let shared = MainThreadChecker()
    
    public static let defaultThreshold: Double = 7.0
    
    private let mainRunLoopSemaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
    private var mainRunLoopObserver: CFRunLoopObserver? = nil
    private var mainRunLoopActivity: CFRunLoopActivity = .entry
    private(set) public var running: Bool = false
    private var checkWrokItem: DispatchWorkItem? = nil
    
    private var relativeState: RelativeState = .common
    private let stateSemaphore: DispatchSemaphore = DispatchSemaphore(value: 1)
    
    private var willEnterForegroundObserverOrNil: NSObjectProtocol? = nil
    private var didEnterBackgroundObserverOrNil: NSObjectProtocol? = nil
    
    /// Asynchronously start checking.
    /// - Parameters:
    ///   - threshold: Timeinterval to trigger an alarm. If not specified, a default value of 7.0 seconds will be applied to monitor the main thread.
    ///   - mode: In common mode, checker will not check unless no debugger's being attached. In parent mode, checker will check anyway.
    ///   - alarmingAction: Action that will be executed when an alarm is triggered due to exceeding the threshold time.
    public func start(checking threshold: Double = MainThreadChecker.defaultThreshold, in mode: CheckingMode = .commonMode, using alarmingAction: Optional<()->Void> = nil) {
        
        if amIBeingDebugged() && mode != .parentMode { return } // It's under developing and the monitoring should not take effect.
        
        guard self.running != true, threshold > 0 else { return }
        
        self.willEnterForegroundObserverOrNil = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.willEnterForeground()
        }
        
        self.didEnterBackgroundObserverOrNil = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.didEnterBackground()
        }
        
        // Create the observer then make it observe the main runloop.
        self.mainRunLoopObserver = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFOptionFlags(CFRunLoopActivity.allActivities.rawValue), true, 0) { [weak self] observerOrNil, activity in
            guard let self = self else { return }
            self.mainRunLoopActivity = activity
            self.mainRunLoopSemaphore.signal()
        }
        guard self.mainRunLoopObserver != nil else { return }
        CFRunLoopAddObserver(CFRunLoopGetMain(), self.mainRunLoopObserver, CFRunLoopMode.commonModes)
        
        self.checkWrokItem = DispatchWorkItem { [weak self] in
            self?.running = true
            while let self = self, let workItem = self.checkWrokItem, !workItem.isCancelled {
                // Wait for main runloop synchronize its own activity change out before time out, or there must be any lag or block happening.
                let result = self.mainRunLoopSemaphore.wait(timeout: DispatchTime.now() + threshold)
                
                self.stateSemaphore.wait() // Ensure thread safe on `self.relativeState`.
                
                if self.relativeState == .common {
                    if result == .timedOut {
                        if self.mainRunLoopActivity == .beforeSources || self.mainRunLoopActivity == .afterWaiting {
                            alarmingAction?() // Trigger the alarm.
                        }
                    }
                } else if self.relativeState == .toBackground {
                    // App is now at background and the main thread should be blocked after a while.
                } else if self.relativeState == .toForeground {
                    // App is back to foreground but this time we should ignore.
                    self.relativeState = .common
                }
                
                self.stateSemaphore.signal()
                
            }
            self?.running = false
        }
        self.startAsyncCheck()
    }
    
    
    /// Asynchronously stop and cancel the check.
    public func cancel() {
        self.checkWrokItem?.cancel()
        guard let observer = self.mainRunLoopObserver else { return }
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, CFRunLoopMode.commonModes)
        self.mainRunLoopObserver = nil
        if let willEnterForegroundObserver = self.willEnterForegroundObserverOrNil {
            NotificationCenter.default.removeObserver(willEnterForegroundObserver, name: UIApplication.willEnterForegroundNotification, object: nil)
        }
        if let didEnterBackgroundObserver = self.didEnterBackgroundObserverOrNil {
            NotificationCenter.default.removeObserver(didEnterBackgroundObserver, name: UIApplication.willEnterForegroundNotification, object: nil)
        }
    }
    
    private func startAsyncCheck() {
        guard let workItem = self.checkWrokItem else { return }
        DispatchQueue.global(qos: .background).async(execute: workItem)
    }
    
    private func willEnterForeground() {
        self.stateSemaphore.wait()
        self.relativeState = .toForeground
        self.stateSemaphore.signal()
        
    }
    
    private func didEnterBackground() {
        self.stateSemaphore.wait()
        self.relativeState = .toBackground
        self.stateSemaphore.signal()
    }
}

/// Detect whether it's under development environment.
/// Converted to Swift version from Apple's official C example: https://developer.apple.com/library/archive/qa/qa1361/_index.html
/// - Returns: If there's a debugger attaching.
fileprivate func amIBeingDebugged() -> Bool {
    var info = kinfo_proc()
    info.kp_proc.p_flag = 0
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

    guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0 else { return true }

    return (info.kp_proc.p_flag & P_TRACED) != 0
}
