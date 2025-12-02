import SwiftUI
import UserNotifications

/// MiniPNG 应用程序入口
@main
struct MiniPNGApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = CompressionViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: viewModel)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // 文件菜单
            CommandGroup(replacing: .newItem) {
                Button("添加图片...") {
                    viewModel.openFilePicker()
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("清空列表") {
                    viewModel.clearAll()
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(viewModel.images.isEmpty)
            }
            
            // 编辑菜单
            CommandGroup(after: .pasteboard) {
                Divider()
                
                Button("全选") {
                    // 未来可以实现多选功能
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            
            // 压缩菜单
            CommandMenu("压缩") {
                Button("开始压缩") {
                    viewModel.compressAll()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(viewModel.images.isEmpty || viewModel.isCompressing)
                
                Divider()
                
                Picker("压缩质量", selection: $viewModel.quality) {
                    ForEach(CompressionService.Quality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                
                Divider()
                
                Toggle("替换源文件", isOn: $viewModel.replaceOriginal)
            }
            
            // 帮助菜单
            CommandGroup(replacing: .help) {
                Button("关于 MiniPNG") {
                    showAboutPanel()
                }
                
                Divider()
                
                Link("访问 GitHub", destination: URL(string: "https://github.com")!)
            }
        }
    }
    
    private func showAboutPanel() {
        let alert = NSAlert()
        alert.messageText = "MiniPNG"
        alert.informativeText = "版本 1.0.0\n\n高效的图片压缩工具\n支持 PNG、JPEG、WebP、GIF 格式\n\n使用 pngquant、mozjpeg、oxipng 等开源压缩引擎"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }
}

/// App Delegate 处理应用级别事件
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 确保应用获得焦点
        NSApp.activate(ignoringOtherApps: true)
        
        // 请求通知权限（仅在 bundle 环境下）
        NotificationManager.shared.requestAuthorization()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}


/// 通知管理
class NotificationManager {
    static let shared = NotificationManager()
    
    /// 检查是否在有效的 bundle 环境中运行
    private var isValidBundle: Bool {
        Bundle.main.bundleIdentifier != nil
    }
    
    /// 请求通知权限
    func requestAuthorization() {
        guard isValidBundle else { return }
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    /// 发送压缩完成通知
    func sendCompletionNotification(totalCount: Int, savedSize: String, averageRatio: Double) {
        guard isValidBundle else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "压缩完成"
        content.body = "已压缩 \(totalCount) 张图片，节省 \(savedSize)，平均压缩 \(String(format: "%.1f", averageRatio))%"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
}
