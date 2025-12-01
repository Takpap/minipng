import Foundation

/// 图片压缩状态
enum CompressionStatus: Equatable {
    case pending          // 等待压缩
    case compressing      // 压缩中
    case completed        // 压缩完成
    case failed(String)   // 压缩失败
    
    var description: String {
        switch self {
        case .pending: return "等待中"
        case .compressing: return "压缩中..."
        case .completed: return "已完成"
        case .failed(let error): return "失败: \(error)"
        }
    }
}

/// 图片项数据模型
struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL                          // 原始文件路径
    let originalSize: Int64               // 原始大小 (bytes)
    var compressedSize: Int64?            // 压缩后大小
    var status: CompressionStatus = .pending
    var outputURL: URL?                   // 输出文件路径
    
    /// 文件名
    var fileName: String {
        url.lastPathComponent
    }
    
    /// 文件扩展名
    var fileExtension: String {
        url.pathExtension.lowercased()
    }
    
    /// 是否为支持的图片格式
    var isSupported: Bool {
        ["png", "jpg", "jpeg", "webp", "gif"].contains(fileExtension)
    }
    
    /// 图片类型
    var imageType: ImageType {
        switch fileExtension {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "webp": return .webp
        case "gif": return .gif
        default: return .unknown
        }
    }
}

/// 图片类型枚举
enum ImageType {
    case png, jpeg, webp, gif, unknown
    
    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        case .webp: return "WebP"
        case .gif: return "GIF"
        case .unknown: return "未知"
        }
    }
}

// MARK: - ImageItem 扩展属性
extension ImageItem {
    /// 压缩率 (0-100%)
    var compressionRatio: Double? {
        guard let compressed = compressedSize, originalSize > 0 else { return nil }
        return Double(originalSize - compressed) / Double(originalSize) * 100
    }
    
    /// 格式化的原始大小
    var formattedOriginalSize: String {
        ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
    }
    
    /// 格式化的压缩后大小
    var formattedCompressedSize: String? {
        guard let size = compressedSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
