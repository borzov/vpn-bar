#!/usr/bin/env swift

import AppKit
import Foundation

/// Создает квадратную иконку указанного размера с замком VPN Bar.
/// - Parameter size: Размер стороны в пикселях.
/// - Returns: Сгенерированное изображение NSImage.
func createIcon(size: Int) -> NSImage {
    let sizeFloat = CGFloat(size)
    let image = NSImage(size: NSSize(width: sizeFloat, height: sizeFloat))
    image.lockFocus()
    
    // Фон - синий цвет Apple
    let bgColor = NSColor(red: 0, green: 0.478, blue: 1.0, alpha: 1.0)
    bgColor.setFill()
    
    // Закругленный прямоугольник
    let path = NSBezierPath(roundedRect: NSRect(x: sizeFloat * 0.1, y: sizeFloat * 0.1, 
                                                width: sizeFloat * 0.8, height: sizeFloat * 0.8),
                           xRadius: sizeFloat * 0.2, yRadius: sizeFloat * 0.2)
    path.fill()
    
    // Белый символ замка
    NSColor.white.setFill()
    NSColor.white.setStroke()
    
    let centerX = sizeFloat / 2
    let centerY = sizeFloat / 2
    let lockSize = sizeFloat * 0.4
    
    // Дужка замка (полукруг сверху)
    let arcPath = NSBezierPath()
    arcPath.appendArc(withCenter: NSPoint(x: centerX, y: centerY + lockSize * 0.15),
                     radius: lockSize * 0.3,
                     startAngle: 0,
                     endAngle: 180)
    arcPath.lineWidth = sizeFloat * 0.08
    arcPath.stroke()
    
    // Корпус замка (прямоугольник)
    let bodyPath = NSBezierPath(rect: NSRect(x: centerX - lockSize * 0.3,
                                            y: centerY - lockSize * 0.15,
                                            width: lockSize * 0.6,
                                            height: lockSize * 0.5))
    bodyPath.fill()
    
    // Ключевое отверстие (маленький круг)
    let holeSize = sizeFloat * 0.08
    let holePath = NSBezierPath(ovalIn: NSRect(x: centerX - holeSize,
                                              y: centerY - holeSize * 0.5,
                                              width: holeSize * 2,
                                              height: holeSize))
    bgColor.setFill()
    holePath.fill()
    
    image.unlockFocus()
    return image
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let iconsetDir = "Icon.iconset"
let fileManager = FileManager.default

// Создаем директорию iconset
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

for (filename, size) in sizes {
    let image = createIcon(size: size)
    
    guard let tiffData = image.tiffRepresentation,
          let bitmapRep = NSBitmapImageRep(data: tiffData) else {
        continue
    }
    
    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        continue
    }
    
    let filepath = "\(iconsetDir)/\(filename)"
    fileManager.createFile(atPath: filepath, contents: pngData)
    print("Создан: \(filepath)")
}

print("✓ Иконки созданы в \(iconsetDir)")
print("Запустите: iconutil -c icns \(iconsetDir) -o VPNBarApp.icns")

