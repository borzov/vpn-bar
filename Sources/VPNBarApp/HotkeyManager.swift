import AppKit
import Carbon
import os.log

/// Manages registration and handling of global hotkeys.
class HotkeyManager: HotkeyManagerProtocol {
    static let shared = HotkeyManager()

    private var globalHotKeyRef: EventHotKeyRef?
    private var globalHotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "VPNT"), id: 1)
    private var isRegistered = false
    private var callback: (() -> Void)?
    private var eventHandler: EventHandlerRef?

    private var connectionHotKeys: [String: (ref: EventHotKeyRef, callback: () -> Void)] = [:]
    private var hotkeyIDToConnectionID: [UInt32: String] = [:]
    private var nextConnectionHotkeyID: UInt32 = 100

    private var isSetup = false
    /// Flag to prevent use-after-free in event handler callback.
    private var isValid = true
    /// Flag to track if self was retained for event handler.
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
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                guard manager.isValid else {
                    return OSStatus(eventNotHandledErr)
                }

                // Global toggle hotkey
                if hotKeyID.id == manager.globalHotKeyID.id &&
                   hotKeyID.signature == manager.globalHotKeyID.signature {
                    if let callback = manager.callback {
                        DispatchQueue.main.async {
                            guard manager.isValid else { return }
                            callback()
                        }
                    }
                    return noErr
                }

                // Per-connection hotkey
                let connectionSignature = FourCharCode(fromString: "VPNC")
                if hotKeyID.signature == connectionSignature {
                    if let connectionID = manager.hotkeyIDToConnectionID[hotKeyID.id],
                       let entry = manager.connectionHotKeys[connectionID] {
                        let cb = entry.callback
                        DispatchQueue.main.async {
                            guard manager.isValid else { return }
                            cb()
                        }
                        return noErr
                    }
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
            globalHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            self.globalHotKeyRef = ref
            self.isRegistered = true
            Logger.hotkey.info("Global hotkey registered: keyCode=\(keyCode), modifiers=\(modifiers)")
        } else {
            self.callback = nil
            Logger.hotkey.error("Failed to register global hotkey: status=\(status)")
        }
    }

    /// Unregisters the global hotkey and clears the callback.
    func unregisterHotkey() {
        if let ref = globalHotKeyRef, isRegistered {
            UnregisterEventHotKey(ref)
            globalHotKeyRef = nil
            isRegistered = false
        }
        callback = nil
    }

    func registerConnectionHotkey(connectionID: String, keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        unregisterConnectionHotkey(connectionID: connectionID)

        let hotkeyID = nextConnectionHotkeyID
        nextConnectionHotkeyID += 1

        let hotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "VPNC"), id: hotkeyID)

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
            connectionHotKeys[connectionID] = (ref: ref, callback: callback)
            hotkeyIDToConnectionID[hotkeyID] = connectionID
            Logger.hotkey.info("Connection hotkey registered: \(connectionID), keyCode=\(keyCode)")
        } else {
            Logger.hotkey.error("Failed to register connection hotkey: status=\(status)")
        }
    }

    func unregisterConnectionHotkey(connectionID: String) {
        guard let entry = connectionHotKeys.removeValue(forKey: connectionID) else { return }
        UnregisterEventHotKey(entry.ref)
        hotkeyIDToConnectionID = hotkeyIDToConnectionID.filter { $0.value != connectionID }
    }

    func unregisterAllConnectionHotkeys() {
        for (_, entry) in connectionHotKeys {
            UnregisterEventHotKey(entry.ref)
        }
        connectionHotKeys.removeAll()
        hotkeyIDToConnectionID.removeAll()
    }
    
    /// Explicitly cleans up all resources. Should be called when the application terminates.
    func cleanup() {
        Logger.hotkey.info("Cleaning up hotkey manager")

        isValid = false

        unregisterHotkey()
        unregisterAllConnectionHotkeys()

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

