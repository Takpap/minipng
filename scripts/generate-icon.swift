#!/usr/bin/env swift

import AppKit

// 生成应用图标
func generateIcon() {
    let sizes: [Int] = [16, 32, 64, 128, 256, 512, 1024]
    let iconsetPath = "/tmp/MiniPNG.iconset"
    
    // 创建 iconset 目录
    try? FileManager.default.removeItem(atPath: iconsetPath)
    try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
    
    for size in sizes {
        let image = createIconImage(size: size)
        
        // 保存 1x
        saveImage(image, to: "\(iconsetPath)/icon_\(size)x\(size).png")
        
        // 保存 2x (除了 1024)
        if size <= 512 {
            let image2x = createIconImage(size: size * 2)
            saveImage(image2x, to: "\(iconsetPath)/icon_\(size)x\(size)@2x.png")
        }
    }
    
    print("✅ Iconset 创建完成: \(iconsetPath)")
    print("运行以下命令生成 icns:")
    print("iconutil -c icns \(iconsetPath) -o dist/MiniPNG.app/Contents/Resources/AppIcon.icns")
}

func createIconImage(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = CGFloat(size) * 0.2
    
    // 背景 - 深色渐变
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    
    let bgGradient = NSGradient(colors: [
        NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0),
        NSColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
    ])!
    bgGradient.draw(in: bgPath, angle: -45)
    
    // 图标 - 使用 SF Symbol
    let config = NSImage.SymbolConfiguration(pointSize: CGFloat(size) * 0.5, weight: .medium)
    if let symbolImage = NSImage(systemSymbolName: "arrow.down.right.and.arrow.up.left.circle.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        
        // 创建渐变遮罩
        let symbolRect = NSRect(
            x: CGFloat(size) * 0.2,
            y: CGFloat(size) * 0.2,
            width: CGFloat(size) * 0.6,
            height: CGFloat(size) * 0.6
        )
        
        // 绘制带颜色的符号
        let tintedImage = NSImage(size: symbolImage.size)
        tintedImage.lockFocus()
        
        // 绿色渐变
        let gradient = NSGradient(colors: [
            NSColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0),  // 绿色
            NSColor(red: 0.3, green: 0.9, blue: 0.7, alpha: 1.0)   // 薄荷色
        ])!
        
        symbolImage.draw(in: NSRect(origin: .zero, size: symbolImage.size))
        
        NSColor(red: 0.25, green: 0.85, blue: 0.55, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: symbolImage.size).fill(using: .sourceAtop)
        
        tintedImage.unlockFocus()
        
        tintedImage.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    
    image.unlockFocus()
    return image
}

func saveImage(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }
    try? pngData.write(to: URL(fileURLWithPath: path))
}

generateIcon()
