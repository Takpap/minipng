import Foundation
import SwiftUI
import UniformTypeIdentifiers
import AppKit

/// 压缩视图模型
@MainActor
class CompressionViewModel: ObservableObject {
    @Published var images: [ImageItem] = []
    @Published var isCompressing = false
    @Published var quality: CompressionService.Quality = .medium {
        didSet {
            if oldValue != quality {
                // 质量变化时，重置已完成图片的状态
                resetCompletedImages()
            }
        }
    }
    @Published var replaceOriginal = false  // 是否替换源文件，默认关闭
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let compressionService = CompressionService()
    
    /// 重置已完成图片的状态（用于重新压缩）
    func resetCompletedImages() {
        for i in images.indices {
            if case .completed = images[i].status {
                images[i].status = .pending
                images[i].compressedSize = nil
                images[i].outputURL = nil
            }
        }
    }
    
    
    /// 总图片数
    var totalCount: Int { images.count }
    
    /// 已完成数
    var completedCount: Int {
        images.filter { if case .completed = $0.status { return true }; return false }.count
    }
    
    /// 总节省大小
    var totalSaved: Int64 {
        images.compactMap { item -> Int64? in
            guard let compressed = item.compressedSize else { return nil }
            return item.originalSize - compressed
        }.reduce(0, +)
    }
    
    /// 格式化的总节省大小
    var formattedTotalSaved: String {
        ByteCountFormatter.string(fromByteCount: totalSaved, countStyle: .file)
    }
    
    /// 平均压缩率
    var averageCompressionRatio: Double {
        let ratios = images.compactMap { $0.compressionRatio }
        guard !ratios.isEmpty else { return 0 }
        return ratios.reduce(0, +) / Double(ratios.count)
    }
    
    /// 添加图片
    func addImages(urls: [URL]) {
        let fileManager = FileManager.default
        
        for url in urls {
            // 检查是否为目录
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 递归添加目录中的图片
                    addImagesFromDirectory(url)
                } else {
                    addSingleImage(url)
                }
            }
        }
    }
    
    /// 从目录添加图片
    private func addImagesFromDirectory(_ directory: URL) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { return }
        
        while let fileURL = enumerator.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if ["png", "jpg", "jpeg", "webp", "gif"].contains(ext) {
                addSingleImage(fileURL)
            }
        }
    }
    
    /// 添加单个图片
    private func addSingleImage(_ url: URL) {
        // 检查是否已添加
        guard !images.contains(where: { $0.url == url }) else { return }
        
        // 获取文件大小
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else { return }
        
        let item = ImageItem(url: url, originalSize: size)
        
        // 只添加支持的格式
        if item.isSupported {
            images.append(item)
        }
    }
    
    /// 移除图片
    func removeImage(_ item: ImageItem) {
        images.removeAll { $0.id == item.id }
    }
    
    /// 清空所有图片
    func clearAll() {
        images.removeAll()
    }
    
    /// 最大并发数
    private let maxConcurrency = 4
    
    /// 开始压缩所有图片（并发）
    func compressAll() {
        guard !isCompressing else { return }
        isCompressing = true
        
        Task {
            // 收集需要压缩的图片信息
            var pendingTasks: [(index: Int, item: ImageItem, outputURL: URL)] = []
            for i in images.indices {
                if case .completed = images[i].status { continue }
                images[i].status = .pending
                let item = images[i]
                let outputURL = getOutputURL(for: item)
                pendingTasks.append((i, item, outputURL))
            }
            
            let currentQuality = quality
            
            // 并发压缩，限制并发数
            await withTaskGroup(of: (Int, Result<(Int64, URL), Error>).self) { group in
                var taskIterator = pendingTasks.makeIterator()
                var runningCount = 0
                
                // 辅助函数：添加任务
                func addNextTask() -> Bool {
                    guard let task = taskIterator.next() else { return false }
                    let (index, item, outputURL) = task
                    group.addTask { [compressionService] in
                        do {
                            let size = try await compressionService.compress(item: item, output: outputURL, quality: currentQuality)
                            return (index, .success((size, outputURL)))
                        } catch {
                            return (index, .failure(error))
                        }
                    }
                    return true
                }
                
                // 启动初始批次
                while runningCount < maxConcurrency, addNextTask() {
                    runningCount += 1
                }
                
                // 标记初始批次为压缩中
                for i in 0..<min(maxConcurrency, pendingTasks.count) {
                    images[pendingTasks[i].index].status = .compressing
                }
                
                var nextToStart = maxConcurrency
                
                // 处理结果并启动新任务
                for await (index, result) in group {
                    switch result {
                    case .success(let (size, url)):
                        images[index].compressedSize = size
                        images[index].outputURL = url
                        images[index].status = .completed
                    case .failure(let error):
                        images[index].status = .failed(error.localizedDescription)
                    }
                    
                    // 启动下一个任务
                    if nextToStart < pendingTasks.count {
                        let nextTask = pendingTasks[nextToStart]
                        images[nextTask.index].status = .compressing
                        let (nextIndex, nextItem, nextOutputURL) = nextTask
                        group.addTask { [compressionService] in
                            do {
                                let size = try await compressionService.compress(item: nextItem, output: nextOutputURL, quality: currentQuality)
                                return (nextIndex, .success((size, nextOutputURL)))
                            } catch {
                                return (nextIndex, .failure(error))
                            }
                        }
                        nextToStart += 1
                    }
                }
            }
            
            // 压缩完成，发送通知和声音
            if completedCount > 0 {
                sendCompletionNotification()
                playCompletionSound()
            }
            
            isCompressing = false
        }
    }
    
    /// 发送压缩完成通知
    private func sendCompletionNotification() {
        NotificationManager.shared.sendCompletionNotification(
            totalCount: completedCount,
            savedSize: formattedTotalSaved,
            averageRatio: averageCompressionRatio
        )
    }
    
    /// 播放完成音效
    private func playCompletionSound() {
        NSSound(named: .init("Glass"))?.play()
    }
    
    
    /// 获取输出文件路径
    private func getOutputURL(for item: ImageItem) -> URL {
        if replaceOriginal {
            return item.url
        } else {
            let directory = item.url.deletingLastPathComponent()
            let name = item.url.deletingPathExtension().lastPathComponent
            let ext = item.url.pathExtension
            return directory.appendingPathComponent("\(name)-min.\(ext)")
        }
    }
    
    /// 打开文件选择器
    func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.png, .jpeg, .webP, .gif]
        
        if panel.runModal() == .OK {
            addImages(urls: panel.urls)
        }
    }
    
    /// 在 Finder 中显示输出文件
    func showInFinder(_ item: ImageItem) {
        guard let outputURL = item.outputURL else { return }
        NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: "")
    }
}
