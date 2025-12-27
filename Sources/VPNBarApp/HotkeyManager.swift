import AppKit
import Carbon
import os.log

/// Управляет регистрацией и обработкой глобальных горячих клавиш.
class HotkeyManager: HotkeyManagerProtocol {
    static let shared = HotkeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var hotKeyID = EventHotKeyID(signature: FourCharCode(fromString: "VPNT"), id: 1)
    private var isRegistered = false
    private var callback: (() -> Void)?
    private var eventHandler: EventHandlerRef?
    
    private var isSetup = false
    
    private init() {
        setupEventHandler()
    }
    
    private func setupEventHandler() {
        guard !isSetup else { return }
        
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        
        let userData = Unmanaged.passUnretained(self).toOpaque()
        
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
                
                if hotKeyID.id == manager.hotKeyID.id && 
                   hotKeyID.signature == manager.hotKeyID.signature {
                    if let callback = manager.callback {
                        DispatchQueue.main.async {
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
    
    /// Регистрирует глобальную горячую клавишу.
    /// - Parameters:
    ///   - keyCode: Код клавиши.
    ///   - modifiers: Модификаторы Carbon.
    ///   - callback: Обработчик нажатия.
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
    
    /// Отменяет регистрацию горячей клавиши и очищает callback.
    func unregisterHotkey() {
        if let ref = hotKeyRef, isRegistered {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
            isRegistered = false
        }
        callback = nil
    }
    
    /// Явно очищает все ресурсы. Должен вызываться при завершении приложения.
    func cleanup() {
        Logger.hotkey.info("Cleaning up hotkey manager")
        unregisterHotkey()
        
        if let handler = eventHandler {
            RemoveEventHandler(handler)
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

