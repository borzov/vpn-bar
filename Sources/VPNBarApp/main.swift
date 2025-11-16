import AppKit

// Настраиваем приложение как меню-бар приложение (без иконки в Dock)
// LSUIElement настраивается в Info.plist при создании .app bundle
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()

