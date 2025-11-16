#!/usr/bin/env python3
"""
Простой скрипт для создания иконки VPNBarApp
Создает простую иконку с символом сети/замка
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("PIL не установлен, используем альтернативный метод")

import os
import sys

def create_icon(size):
    """Создает иконку заданного размера"""
    # Создаем изображение с прозрачным фоном
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Цвета
    bg_color = (0, 122, 255, 255)  # Синий цвет Apple
    icon_color = (255, 255, 255, 255)  # Белый
    
    # Рисуем закругленный прямоугольник как фон
    margin = int(size * 0.1)
    draw.rounded_rectangle(
        [margin, margin, size - margin, size - margin],
        radius=int(size * 0.2),
        fill=bg_color
    )
    
    # Рисуем символ замка (упрощенный)
    center_x = size // 2
    center_y = size // 2
    lock_size = int(size * 0.4)
    
    # Корпус замка (прямоугольник с закругленным верхом)
    lock_top = center_y - lock_size // 4
    lock_bottom = center_y + lock_size // 2
    lock_left = center_x - lock_size // 2
    lock_right = center_x + lock_size // 2
    
    # Верхняя часть (дужка)
    draw.arc(
        [lock_left, lock_top - lock_size // 2, lock_right, lock_top + lock_size // 2],
        start=0,
        end=180,
        fill=icon_color,
        width=int(size * 0.08)
    )
    
    # Корпус
    draw.rectangle(
        [lock_left, lock_top, lock_right, lock_bottom],
        fill=icon_color,
        outline=icon_color
    )
    
    # Ключевое отверстие (маленький круг)
    key_hole_size = int(size * 0.08)
    draw.ellipse(
        [center_x - key_hole_size, center_y - key_hole_size // 2,
         center_x + key_hole_size, center_y + key_hole_size // 2],
        fill=bg_color
    )
    
    return img

def main():
    iconset_dir = "Icon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    
    if not HAS_PIL:
        print("Установите Pillow: pip3 install Pillow")
        return 1
    
    for filename, size in sizes.items():
        img = create_icon(size)
        filepath = os.path.join(iconset_dir, filename)
        img.save(filepath, "PNG")
        print(f"Создан: {filepath}")
    
    # Создаем .icns
    os.system(f"iconutil -c icns {iconset_dir} -o VPNBarApp.icns")
    
    if os.path.exists("VPNBarApp.icns"):
        print("✓ Иконка создана: VPNBarApp.icns")
        return 0
    else:
        print("⚠ Не удалось создать .icns файл")
        return 1

if __name__ == "__main__":
    sys.exit(main())

