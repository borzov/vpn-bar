import AppKit
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "VPNT"), id: 1)
    private var isRegistered = false
    private var callback: (() -> Void)?
    private var eventHandler: EventHandlerRef?
    
    private init() {
        setupEventHandler()
    }
    
    private func setupEventHandler() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        let eventHandlerUPP: EventHandlerUPP = { (nextHandler, theEvent, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            
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
                if hotKeyID.id == manager.hotKeyID.id && hotKeyID.signature == manager.hotKeyID.signature {
                    DispatchQueue.main.async {
                        manager.callback?()
                    }
                    return noErr
                }
            }
            
            return OSStatus(eventNotHandledErr)
        }
        
        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            eventHandlerUPP,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
        
        self.eventHandler = handlerRef
    }
    
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
        }
    }
    
    func unregisterHotkey() {
        if let ref = hotKeyRef, isRegistered {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            isRegistered = false
        }
        callback = nil
    }
    
    deinit {
        unregisterHotkey()
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
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

