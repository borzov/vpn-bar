#!/bin/bash

# Создает иконку для VPNBarApp используя SF Symbols

ICONSET_DIR="Icon.iconset"
APP_ICON="VPNBarApp.icns"

echo "Создание иконки для VPNBarApp..."

# Создаем временный Swift скрипт для генерации иконки
cat > /tmp/create_vpn_icon.swift << 'EOF'
import AppKit
import Foundation

func createIcon(size: Int, symbolName: String) -> NSImage? {
    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(size * 2), weight: .medium)
    
    // Пробуем разные символы для VPN
    let symbols = [
        "network.badge.shield.half.filled",
        "lock.shield.fill",
        "network",
        "lock.icloud.fill"
    ]
    
    for symbol in symbols {
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) {
            let symbolImage = image.withSymbolConfiguration(config)
            let finalImage = NSImage(size: NSSize(width: size, height: size))
            finalImage.lockFocus()
            NSColor.controlAccentColor.setFill()
            NSRect(origin: .zero, size: finalImage.size).fill()
            symbolImage?.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            finalImage.unlockFocus()
            return finalImage
        }
    }
    
    // Fallback: создаем простую иконку программно
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    // Фон
    NSColor.systemBlue.setFill()
    NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.2, yRadius: size * 0.2).fill()
    
    // Простой символ замка
    let lockPath = NSBezierPath()
    let centerX = CGFloat(size) / 2
    let centerY = CGFloat(size) / 2
    let lockSize = CGFloat(size) * 0.4
    
    // Корпус замка
    lockPath.appendArc(withCenter: NSPoint(x: centerX, y: centerY + lockSize * 0.2), radius: lockSize * 0.3, startAngle: 0, endAngle: 180)
    lockPath.line(to: NSPoint(x: centerX - lockSize * 0.3, y: centerY - lockSize * 0.2))
    lockPath.line(to: NSPoint(x: centerX + lockSize * 0.3, y: centerY - lockSize * 0.2))
    lockPath.close()
    
    // Дужка
    lockPath.move(to: NSPoint(x: centerX - lockSize * 0.3, y: centerY + lockSize * 0.2))
    lockPath.appendArc(withCenter: NSPoint(x: centerX, y: centerY + lockSize * 0.2), radius: lockSize * 0.3, startAngle: 180, endAngle: 0)
    
    NSColor.white.setStroke()
    lockPath.lineWidth = CGFloat(size) * 0.08
    lockPath.stroke()
    
    image.unlockFocus()
    return image
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]

for size in sizes {
    if let image = createIcon(size: size, symbolName: "network.badge.shield.half.filled") {
        let rep = NSBitmapImageRep(data: image.tiffRepresentation!)
        let pngData = rep?.representation(using: .png, properties: [:])
        
        let filename: String
        if size == 1024 {
            filename = "icon_512x512@2x.png"
        } else if size == 512 {
            filename = "icon_512x512.png"
        } else if size == 256 {
            filename = "icon_256x256@2x.png"
        } else if size == 128 {
            filename = "icon_128x128@2x.png"
        } else if size == 64 {
            filename = "icon_32x32@2x.png"
        } else if size == 32 {
            filename = "icon_32x32.png"
        } else {
            filename = "icon_16x16.png"
        }
        
        if let data = pngData {
            FileManager.default.createFile(atPath: "/tmp/\(filename)", contents: data, attributes: nil)
            print("Создан: \(filename)")
        }
    }
}
EOF

# Запускаем Swift скрипт
swift /tmp/create_vpn_icon.swift

# Копируем созданные иконки в iconset
if [ -d "$ICONSET_DIR" ]; then
    rm -rf "$ICONSET_DIR"
fi
mkdir -p "$ICONSET_DIR"

# Создаем простую иконку используя sips (более надежный способ)
create_simple_icon() {
    local size=$1
    local filename=$2
    
    # Создаем временное изображение
    sips -s format png --setProperty formatOptions low \
         -z $size $size \
         /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/com.apple.network.extension.ico \
         --out "/tmp/$filename" 2>/dev/null || \
    # Если не получилось, создаем простую цветную иконку
    sips -s format png -c sRGB \
         --setProperty formatOptions low \
         -z $size $size \
         /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericNetworkIcon.icns \
         --out "/tmp/$filename" 2>/dev/null || \
    # Последний fallback - создаем через Python/ImageMagick если доступно
    python3 -c "
from PIL import Image, ImageDraw
img = Image.new('RGB', ($size, $size), color='#007AFF')
draw = ImageDraw.Draw(img)
# Рисуем простой символ замка
lock_size = int($size * 0.4)
center = ($size // 2, $size // 2)
# Корпус
draw.rectangle([center[0] - lock_size//2, center[1] - lock_size//4, center[0] + lock_size//2, center[1] + lock_size//2], fill='white', outline='white')
# Дужка
draw.arc([center[0] - lock_size//2, center[1] - lock_size//2, center[0] + lock_size//2, center[1] + lock_size//2], 0, 180, fill='white', width=lock_size//8)
img.save('/tmp/$filename')
" 2>/dev/null
}

# Создаем все необходимые размеры
echo "Генерация иконок разных размеров..."
create_simple_icon 16 "icon_16x16.png"
create_simple_icon 32 "icon_16x16@2x.png"
create_simple_icon 32 "icon_32x32.png"
create_simple_icon 64 "icon_32x32@2x.png"
create_simple_icon 128 "icon_128x128.png"
create_simple_icon 256 "icon_128x128@2x.png"
create_simple_icon 256 "icon_256x256.png"
create_simple_icon 512 "icon_256x256@2x.png"
create_simple_icon 512 "icon_512x512.png"
create_simple_icon 1024 "icon_512x512@2x.png"

# Копируем в iconset
for file in /tmp/icon_*.png; do
    if [ -f "$file" ]; then
        cp "$file" "$ICONSET_DIR/"
    fi
done

# Создаем .icns файл
if [ -f "$APP_ICON" ]; then
    rm "$APP_ICON"
fi

iconutil -c icns "$ICONSET_DIR" -o "$APP_ICON"

if [ -f "$APP_ICON" ]; then
    echo "✓ Иконка создана: $APP_ICON"
else
    echo "⚠ Не удалось создать .icns, но iconset создан в $ICONSET_DIR"
fi

