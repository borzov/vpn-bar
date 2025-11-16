import AppKit
import Combine

class SettingsWindowController {
    static let shared = SettingsWindowController()
    
    private var window: NSWindow?
    private var updateIntervalTextField: NSTextField?
    private var cancellables = Set<AnyCancellable>()
    private let vpnManager = VPNManager.shared
    private let settingsManager = SettingsManager.shared
    
    private init() {
        createWindow()
    }
    
    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 200),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = NSLocalizedString("VPN Bar Settings", comment: "")
        window.center()
        window.isReleasedWhenClosed = false
        
        // Создаем главный контейнер с отступами
        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]
        
        // Главный вертикальный стек
        let mainStack = NSStackView()
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.distribution = .fill
        mainStack.spacing = 20
        mainStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        // Заголовок
        let titleLabel = NSTextField(labelWithString: NSLocalizedString("Application Settings", comment: ""))
        titleLabel.font = NSFont.systemFont(ofSize: 18, weight: .medium)
        titleLabel.alignment = .center
        mainStack.addArrangedSubview(titleLabel)
        
        // Секция: Интервал обновления
        let intervalSection = createIntervalSection()
        mainStack.addArrangedSubview(intervalSection)
        
        // Добавляем стек в contentView
        contentView.addSubview(mainStack)
        
        // Устанавливаем constraints
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mainStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor)
        ])
        
        window.contentView = contentView
        self.window = window
        
        // Подписка на изменения интервала
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateIntervalDidChange),
            name: NSNotification.Name("UpdateIntervalDidChange"),
            object: nil
        )
    }
    
    private func createIntervalSection() -> NSView {
        let sectionStack = NSStackView()
        sectionStack.orientation = .vertical
        sectionStack.alignment = .leading
        sectionStack.distribution = .fill
        sectionStack.spacing = 8
        
        // Заголовок секции
        let sectionLabel = NSTextField(labelWithString: NSLocalizedString("Status Update Interval", comment: ""))
        sectionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        sectionStack.addArrangedSubview(sectionLabel)
        
        // Горизонтальный стек для поля ввода
        let inputStack = NSStackView()
        inputStack.orientation = .horizontal
        inputStack.alignment = .centerY
        inputStack.distribution = .fill
        inputStack.spacing = 8
        
        // Текстовое поле
        let textField = NSTextField()
        textField.stringValue = String(format: "%.0f", settingsManager.updateInterval)
        textField.font = NSFont.systemFont(ofSize: 13)
        textField.alignment = .right
        textField.target = self
        textField.action = #selector(updateIntervalChanged(_:))
        textField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        self.updateIntervalTextField = textField
        inputStack.addArrangedSubview(textField)
        
        // Метка "секунд"
        let secondsLabel = NSTextField(labelWithString: NSLocalizedString("seconds", comment: ""))
        secondsLabel.font = NSFont.systemFont(ofSize: 13)
        inputStack.addArrangedSubview(secondsLabel)
        
        // Spacer
        let spacer = NSView()
        spacer.widthAnchor.constraint(equalToConstant: 1).isActive = true
        inputStack.addArrangedSubview(spacer)
        
        sectionStack.addArrangedSubview(inputStack)
        
        // Описание
        let description = NSTextField(wrappingLabelWithString: NSLocalizedString("Status Update Interval Description", comment: ""))
        description.font = NSFont.systemFont(ofSize: 11)
        description.textColor = .secondaryLabelColor
        description.preferredMaxLayoutWidth = 480
        sectionStack.addArrangedSubview(description)
        
        return sectionStack
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateIntervalChanged(_ sender: NSTextField) {
        guard let text = Double(sender.stringValue.trimmingCharacters(in: .whitespaces)) else {
            // Неверное значение, возвращаем предыдущее
            sender.stringValue = String(format: "%.0f", settingsManager.updateInterval)
            return
        }
        
        // Валидация: от 5 до 60 секунд
        let validatedValue = max(5.0, min(60.0, text))
        if validatedValue != text {
            sender.stringValue = String(format: "%.0f", validatedValue)
        }
        
        settingsManager.updateInterval = validatedValue
        vpnManager.updateInterval = validatedValue
        
        // Отправляем уведомление
        NotificationCenter.default.post(name: NSNotification.Name("UpdateIntervalDidChange"), object: nil)
    }
    
    @objc private func updateIntervalDidChange() {
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
    }
    
    func showWindow() {
        // Обновляем значения при открытии окна
        updateIntervalTextField?.stringValue = String(format: "%.0f", settingsManager.updateInterval)
        
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
