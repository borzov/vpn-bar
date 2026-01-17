import AppKit
import Carbon
import os.log

/// Manages registration and handling of global hotkeys.
class HotkeyManager: HotkeyManagerProtocol {
    static let shared = HotkeyManager()

    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "VPNT"), id: 1)
    private var isRegistered = false
    private var callback: (() -> Void)?
    private var eventHandler: EventHandlerRef?

    private var isSetup = false
    /// Flag to prevent use-after-free in event handler callback.
    /// Set to false in deinit and cleanup to prevent callback execution
    /// after manager memory is deallocated. Checked before each callback invocation.
    private var isValid = true
    /// Flag to track if self was retained for event handler.
    /// Used to properly balance retain/release calls.
    private var isRetainedForEventHandler = false

    private init() {
        setupEventHandler()
    }

    deinit {
        // Mark as invalid before cleanup to prevent callback from accessing deallocated memory
        isValid = false
        cleanup()
    }

    private func setupEventHandler() {
        guard !isSetup else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )

        // Use passRetained to ensure manager stays alive during event handler lifetime
        let userData = Unmanaged.passRetained(self).toOpaque()
        isRetainedForEventHandler = true

        let eventHandlerUPP: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else {
                return OSStatus(eventNotHandledErr)
            }

            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            if err == noErr {
                // Use takeUnretainedValue since we retained in passRetained
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                // Safety check: ensure manager hasn't been invalidated
                guard manager.isValid else {
                    return OSStatus(eventNotHandledErr)
                }

                if hotKeyID.id == manager.hotKeyID.id &&
                   hotKeyID.signature == manager.hotKeyID.signature {
                    if let callback = manager.callback {
                        DispatchQueue.main.async {
                            // Double-check validity before executing callback
                            guard manager.isValid else { return }
                            callback()
                        }
                    }
                    return noErr
                }
            }

            return OSStatus(eventNotHandledErr)
        }

        var handlerRef: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerUPP,
            1,
            &eventSpec,
            userData,
            &handlerRef
        )

        if status == noErr {
            self.eventHandler = handlerRef
            self.isSetup = true
        }
    }
    
    /// Registers a global hotkey.
    /// - Parameters:
    ///   - keyCode: Key code.
    ///   - modifiers: Carbon modifiers.
    ///   - callback: Press handler.
    func registerHotkey(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        unregisterHotkey()
        
        self.callback = callback
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            self.hotKeyRef = ref
            self.isRegistered = true
            Logger.hotkey.info("Hotkey registered: keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            self.callback = nil
            Logger.hotkey.error("Failed to register hotkey: status=\(status)")
        }
    }
    
    /// Unregisters the hotkey and clears the callback.
    func unregisterHotkey() {
        if let ref = hotKeyRef, isRegistered {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            isRegistered = false
        }
        callback = nil
    }
    
    /// Explicitly cleans up all resources. Should be called when the application terminates.
    func cleanup() {
        Logger.hotkey.info("Cleaning up hotkey manager")

        // Mark as invalid first to prevent any pending callbacks from executing
        isValid = false

        unregisterHotkey()

        if let handler = eventHandler {
            RemoveEventHandler(handler)
            
            // Release the retained reference from passRetained
            // This balances the retain from setupEventHandler
            if isRetainedForEventHandler {
                Unmanaged.passUnretained(self).release()
                isRetainedForEventHandler = false
            }
            
            eventHandler = nil
        }
        isSetup = false
    }
}

extension FourCharCode {
    init(fromString string: String) {
        var result: FourCharCode = 0
        for (index, char) in string.utf8.prefix(4).enumerated() {
            result |= FourCharCode(char) << (8 * (3 - index))
        }
        self = result
    }
}

