import Cocoa

/// 桌宠渲染视图 —— 负责绘制当前动画帧
class PetView: NSView {

    // MARK: - Properties
    /// 当前需要显示的动画帧
    var currentFrame: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    // MARK: - Init
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing
    override func draw(_ dirtyRect: NSRect) {
        // 清除背景（透明）
        NSColor.clear.set()
        dirtyRect.fill()

        // 绘制当前帧（保持比例居中）
        guard let image = currentFrame else { return }
        let drawRect = aspectFitRect(for: image.size, in: bounds)
        image.draw(in: drawRect,
                   from: .zero,
                   operation: .sourceOver,
                   fraction: 1.0)
    }

    // MARK: - Hit Testing
    /// 仅在非透明像素区域响应鼠标事件
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let image = currentFrame,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              bounds.contains(point) else {
            return nil
        }

        // 将视图坐标转换为图片像素坐标
        let drawRect = aspectFitRect(for: image.size, in: bounds)
        guard drawRect.contains(point) else { return nil }

        let pixelX = Int((point.x - drawRect.origin.x) / drawRect.width * CGFloat(cgImage.width))
        let pixelY = Int((1.0 - (point.y - drawRect.origin.y) / drawRect.height) * CGFloat(cgImage.height))

        // 检查该像素的 alpha 值
        if let alpha = alphaValue(of: cgImage, at: (pixelX, pixelY)), alpha > 10 {
            return super.hitTest(point)
        }
        return nil
    }

    // MARK: - Helpers
    private func aspectFitRect(for imageSize: NSSize, in containerRect: NSRect) -> NSRect {
        let widthRatio = containerRect.width / imageSize.width
        let heightRatio = containerRect.height / imageSize.height
        let scale = min(widthRatio, heightRatio)

        let scaledSize = NSSize(
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )
        return NSRect(
            x: containerRect.midX - scaledSize.width / 2,
            y: containerRect.midY - scaledSize.height / 2,
            width: scaledSize.width,
            height: scaledSize.height
        )
    }

    private func alphaValue(of cgImage: CGImage, at pixel: (Int, Int)) -> UInt8? {
        guard pixel.0 >= 0, pixel.0 < cgImage.width,
              pixel.1 >= 0, pixel.1 < cgImage.height else { return nil }

        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let offset = pixel.1 * bytesPerRow + pixel.0 * bytesPerPixel

        // 假设 RGBA 格式，alpha 在最后一个字节
        if bytesPerPixel >= 4 {
            return ptr[offset + 3]
        }
        return 255 // 非 RGBA 格式默认不透明
    }
}
