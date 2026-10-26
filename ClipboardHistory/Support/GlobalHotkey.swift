import AppKit
import Carbon
import Combine

/// 注册系统全局快捷键；打开列表不依赖辅助功能或输入监控权限。
final class GlobalHotkey: ObservableObject {
    var onTrigger: (() -> Void)?
    @Published private(set) var isRegistered = false
    private var hotkeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let signature: OSType = 0x434C5048 // CLPH

    deinit { unregister() }

    @discardableResult
    func register(modifiers: NSEvent.ModifierFlags, keyCode: UInt32) -> Bool {
        unregister()
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<GlobalHotkey>.fromOpaque(context).takeUnretainedValue()
            var identifier = EventHotKeyID()
            let result = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard result == noErr, identifier.signature == owner.signature,
                  identifier.id == 1 else { return OSStatus(eventNotHandledErr) }
            DispatchQueue.main.async { [weak owner] in owner?.onTrigger?() }
            return noErr
        }, 1, &eventType, context, &handlerRef)
        guard status == noErr else { return false }

        var carbonModifiers: UInt32 = 0
        if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        let result = RegisterEventHotKey(keyCode, carbonModifiers,
                                         EventHotKeyID(signature: signature, id: 1),
                                         GetApplicationEventTarget(), 0, &hotkeyRef)
        guard result == noErr else {
            unregister()
            NSLog("[GlobalHotkey] registration failed: %d", result)
            return false
        }
        isRegistered = true
        return true
    }

    func unregister() {
        if let hotkeyRef { UnregisterEventHotKey(hotkeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotkeyRef = nil
        handlerRef = nil
        isRegistered = false
    }
}
