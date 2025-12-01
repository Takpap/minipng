import Foundation
import AppKit
import UniformTypeIdentifiers

/// 图片压缩服务 - 集成 pngquant, oxipng, mozjpeg, cwebp, gifsicle
actor CompressionService {
    
    /// 压缩质量等级
    enum Quality: Int, CaseIterable {
        case low = 60       // 低质量，高压缩
        case medium = 75    // 中等质量
        case high = 85      // 高质量，低压缩
        
        var pngQualityRange: String {
            switch self {
            case .low: return "40-60"
            case .medium: return "60-80"
            case .high: return "75-90"
            }
        }
        
        var jpegQuality: Int {
            switch self {
            case .low: return 60
            case .medium: return 75
            case .high: return 85
            }
        }
        
        var webpQuality: Int {
            switch self {
            case .low: return 60
            case .medium: return 75
            case .high: return 85
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return "高压缩"
            case .medium: return "均衡"
            case .high: return "高质量"
            }
        }
    }
    
    // MARK: - 工具路径
    
    private struct Tools {
        let pngquant: URL?
        let oxipng: URL?
        let cjpeg: URL?
        let djpeg: URL?  // 用于解码 JPEG
        let cwebp: URL?
        let gifsicle: URL?
    }
    
    private var tools: Tools
    
    init() {
        // 从 bundle 或系统路径加载工具
        tools = Tools(
            pngquant: Self.findTool("pngquant"),
            oxipng: Self.findTool("oxipng"),
            cjpeg: Self.findTool("cjpeg"),
            djpeg: Self.findTool("djpeg"),
            cwebp: Self.findTool("cwebp"),
            gifsicle: Self.findTool("gifsicle")
        )
    }
    
    /// 查找工具路径 - 优先从 bundle，其次系统路径
    private static func findTool(_ name: String) -> URL? {
        // 1. 从 bundle Resources/bin 目录查找
        if let resourceURL = Bundle.main.resourceURL {
            let bundlePath = resourceURL.appendingPathComponent("bin/\(name)")
            if FileManager.default.fileExists(atPath: bundlePath.path) {
                return bundlePath
            }
        }
        
        // 2. 系统路径查找
        let systemPaths = [
            "/opt/homebrew/bin/\(name)",
            "/opt/homebrew/opt/mozjpeg/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/local/opt/mozjpeg/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        
        for path in systemPaths {
            if FileManager.default.fileExists(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        
        return nil
    }
    
    // MARK: - 统一压缩接口
    
    /// 根据图片类型压缩
    func compress(item: ImageItem, output: URL, quality: Quality) async throws -> Int64 {
        switch item.imageType {
        case .png:
            return try await compressPNG(input: item.url, output: output, quality: quality)
        case .jpeg:
            return try await compressJPEG(input: item.url, output: output, quality: quality)
        case .webp:
            return try await compressWebP(input: item.url, output: output, quality: quality)
        case .gif:
            return try await compressGIF(input: item.url, output: output, quality: quality)
        case .unknown:
            throw CompressionError.unsupportedFormat
        }
    }
    
    // MARK: - PNG 压缩
    
    /// 压缩 PNG (pngquant 有损 + oxipng 无损优化)
    func compressPNG(input: URL, output: URL, quality: Quality) async throws -> Int64 {
        guard let pngquant = tools.pngquant else {
            throw CompressionError.toolNotFound("pngquant")
        }
        
        // 如果是替换模式，先输出到临时文件
        let tempOutput = output == input ? 
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png") : output
        
        // Step 1: pngquant 有损压缩
        try runProcess(
            executable: pngquant,
            arguments: [
                "--quality=\(quality.pngQualityRange)",
                "--force",
                "--output", tempOutput.path,
                input.path
            ]
        )
        
        // Step 2: oxipng 无损优化 (可选)
        if let oxipng = tools.oxipng {
            try? runProcess(
                executable: oxipng,
                arguments: ["-o", "2", "-q", tempOutput.path]
            )
        }
        
        // 如果是替换模式，移动临时文件到目标
        if output == input {
            try FileManager.default.removeItem(at: output)
            try FileManager.default.moveItem(at: tempOutput, to: output)
        }
        
        return try getFileSize(output)
    }
    
    // MARK: - JPEG 压缩
    
    /// 压缩 JPEG (mozjpeg: djpeg 解码 -> cjpeg 重新编码)
    func compressJPEG(input: URL, output: URL, quality: Quality) async throws -> Int64 {
        guard let cjpeg = tools.cjpeg, let djpeg = tools.djpeg else {
            throw CompressionError.toolNotFound("mozjpeg (cjpeg/djpeg)")
        }
        
        let tempOutput = output == input ?
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg") : output
        
        // 使用管道: djpeg (解码) -> cjpeg (重新编码)
        try runJPEGPipeline(
            djpeg: djpeg,
            cjpeg: cjpeg,
            input: input,
            output: tempOutput,
            quality: quality.jpegQuality
        )
        
        if output == input {
            try FileManager.default.removeItem(at: output)
            try FileManager.default.moveItem(at: tempOutput, to: output)
        }
        
        return try getFileSize(output)
    }
    
    /// 运行 JPEG 压缩管道 (djpeg | cjpeg)
    private func runJPEGPipeline(djpeg: URL, cjpeg: URL, input: URL, output: URL, quality: Int) throws {
        // djpeg 进程 - 解码 JPEG 到 stdout
        let djpegProcess = Process()
        djpegProcess.executableURL = djpeg
        djpegProcess.arguments = [input.path]
        
        // cjpeg 进程 - 从 stdin 读取并编码
        let cjpegProcess = Process()
        cjpegProcess.executableURL = cjpeg
        cjpegProcess.arguments = [
            "-quality", "\(quality)",
            "-optimize",
            "-progressive",
            "-outfile", output.path
        ]
        
        // 创建管道连接 djpeg stdout -> cjpeg stdin
        let pipe = Pipe()
        djpegProcess.standardOutput = pipe
        cjpegProcess.standardInput = pipe
        
        let djpegErrorPipe = Pipe()
        let cjpegErrorPipe = Pipe()
        djpegProcess.standardError = djpegErrorPipe
        cjpegProcess.standardError = cjpegErrorPipe
        
        do {
            try djpegProcess.run()
        } catch {
            throw CompressionError.processFailed("无法启动 djpeg: \(error.localizedDescription), 路径: \(djpeg.path)")
        }
        
        do {
            try cjpegProcess.run()
        } catch {
            djpegProcess.terminate()
            throw CompressionError.processFailed("无法启动 cjpeg: \(error.localizedDescription), 路径: \(cjpeg.path)")
        }
        
        djpegProcess.waitUntilExit()
        cjpegProcess.waitUntilExit()
        
        // 检查 djpeg 错误
        if djpegProcess.terminationStatus != 0 {
            let errorData = djpegErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "djpeg 解码失败"
            throw CompressionError.processFailed("djpeg 错误 (\(djpegProcess.terminationStatus)): \(errorMessage)")
        }
        
        // 检查 cjpeg 错误
        if cjpegProcess.terminationStatus != 0 {
            let errorData = cjpegErrorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "cjpeg 编码失败"
            throw CompressionError.processFailed("cjpeg 错误 (\(cjpegProcess.terminationStatus)): \(errorMessage)")
        }
    }
    
    /// 系统 API 压缩 JPEG (降级方案)
    private func compressJPEGWithSystemAPI(input: URL, output: URL, quality: Quality) async throws -> Int64 {
        guard let image = NSImage(contentsOf: input),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw CompressionError.invalidImage
        }
        
        guard let destination = CGImageDestinationCreateWithURL(
            output as CFURL,
            UTType.jpeg.identifier as CFString,
            1, nil
        ) else {
            throw CompressionError.cannotCreateDestination
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Double(quality.jpegQuality) / 100.0
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else {
            throw CompressionError.compressionFailed
        }
        
        return try getFileSize(output)
    }
    
    // MARK: - WebP 压缩
    
    /// 压缩 WebP
    func compressWebP(input: URL, output: URL, quality: Quality) async throws -> Int64 {
        guard let cwebp = tools.cwebp else {
            throw CompressionError.toolNotFound("cwebp")
        }
        
        let tempOutput = output == input ?
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".webp") : output
        
        try runProcess(
            executable: cwebp,
            arguments: [
                "-q", "\(quality.webpQuality)",
                "-m", "6",  // 压缩方法 (0-6, 6最慢但最好)
                input.path,
                "-o", tempOutput.path
            ]
        )
        
        if output == input {
            try FileManager.default.removeItem(at: output)
            try FileManager.default.moveItem(at: tempOutput, to: output)
        }
        
        return try getFileSize(output)
    }
    
    // MARK: - GIF 压缩
    
    /// 压缩 GIF
    func compressGIF(input: URL, output: URL, quality: Quality) async throws -> Int64 {
        guard let gifsicle = tools.gifsicle else {
            throw CompressionError.toolNotFound("gifsicle")
        }
        
        // gifsicle 优化级别: -O1, -O2, -O3
        let optimizeLevel: String
        switch quality {
        case .low: optimizeLevel = "-O3"
        case .medium: optimizeLevel = "-O2"
        case .high: optimizeLevel = "-O1"
        }
        
        try runProcess(
            executable: gifsicle,
            arguments: [
                optimizeLevel,
                "--colors", "256",
                input.path,
                "-o", output.path
            ]
        )
        
        return try getFileSize(output)
    }
    
    // MARK: - 辅助方法
    
    /// 运行外部进程
    private func runProcess(executable: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        // pngquant 返回 99 表示质量无法满足，不视为错误
        if process.terminationStatus != 0 && process.terminationStatus != 99 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "未知错误"
            throw CompressionError.processFailed(errorMessage)
        }
    }
    
    /// 获取文件大小
    private func getFileSize(_ url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// 获取工具状态
    var toolsStatus: [String: Bool] {
        [
            "pngquant": tools.pngquant != nil,
            "oxipng": tools.oxipng != nil,
            "cjpeg (mozjpeg)": tools.cjpeg != nil,
            "cwebp": tools.cwebp != nil,
            "gifsicle": tools.gifsicle != nil
        ]
    }
}

/// 压缩错误
enum CompressionError: LocalizedError {
    case toolNotFound(String)
    case processFailed(String)
    case invalidImage
    case cannotCreateDestination
    case compressionFailed
    case unsupportedFormat
    
    var errorDescription: String? {
        switch self {
        case .toolNotFound(let tool):
            return "未找到压缩工具: \(tool)"
        case .processFailed(let msg):
            return "压缩失败: \(msg)"
        case .invalidImage:
            return "无法读取图片"
        case .cannotCreateDestination:
            return "无法创建输出文件"
        case .compressionFailed:
            return "压缩失败"
        case .unsupportedFormat:
            return "不支持的图片格式"
        }
    }
}
