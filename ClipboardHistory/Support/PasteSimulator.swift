import AppKit
import ApplicationServices

/// 恢复打开列表前的应用，确认前台切换完成后发送一次 ⌘V。
enum PasteSimulator {
    enum PasteError: Error {
        case permissionDenied
        case targetUnavailable
        case activationTimedOut
        case eventCreationFailed
    }

    static func paste(pid: pid_t, completion: @escaping (Error?) -> Void) {
        guard AXIsProcessTrusted() else {
            completion(PasteError.permissionDenied)
            return
        }
        guard pid > 0, pid != ProcessInfo.processInfo.processIdentifier,
              let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else {
            completion(PasteError.targetUnavailable)
            return
        }
        guard app.activate(options: []) else {
            completion(PasteError.targetUnavailable)
            return
        }
        waitForActivation(app, attempts: 20, completion: completion)
    }

    private static func waitForActivation(_ app: NSRunningApplication, attempts: Int,
                                           completion: @escaping (Error?) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard !app.isTerminated else {
                completion(PasteError.targetUnavailable)
                return
            }
            guard AXIsProcessTrusted() else {
                completion(PasteError.permissionDenied)
                return
            }
            let heldModifiers = CGEventSource.flagsState(.combinedSessionState)
                .intersection([.maskCommand, .maskShift, .maskAlternate, .maskControl])
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
                  heldModifiers.isEmpty else {
                if attempts > 0 {
                    waitForActivation(app, attempts: attempts - 1, completion: completion)
                } else {
                    completion(PasteError.activationTimedOut)
                }
                return
            }
            let source = CGEventSource(stateID: .privateState)
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                completion(PasteError.eventCreationFailed)
                return
            }
            down.flags = .maskCommand
            up.flags = .maskCommand
            down.postToPid(app.processIdentifier)
            up.postToPid(app.processIdentifier)
            completion(nil)
        }
    }
}
