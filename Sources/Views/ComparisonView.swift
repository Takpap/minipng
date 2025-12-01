import SwiftUI
import AppKit

/// 图片压缩前后对比视图
struct ComparisonView: View {
    let originalURL: URL
    let compressedURL: URL?
    let originalSize: Int64
    let compressedSize: Int64?
    @Binding var isPresented: Bool
    
    @State private var sliderPosition: CGFloat = 0.5
    @State private var viewMode: ViewMode = .slider
    @State private var escMonitor: Any?
    
    enum ViewMode: String, CaseIterable {
        case slider = "滑块对比"
        case sideBySide = "左右对比"
        case original = "仅原图"
        case compressed = "仅压缩后"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbar
            
            Divider()
            
            // 对比区域
            GeometryReader { geometry in
                comparisonContent(size: geometry.size)
            }
            
            Divider()
            
            // 底部信息栏
            infoBar
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            // 添加 ESC 键监听
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
                if event.keyCode == 53 { // ESC 键码
                    DispatchQueue.main.async {
                        self.isPresented = false
                    }
                    return nil
                }
                return event
            }
        }
        .onDisappear {
            // 移除监听器
            if let monitor = escMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
    
    // MARK: - 工具栏
    
    private var toolbar: some View {
        HStack {
            Text("图片对比")
                .font(.headline)
            
            Spacer()
            
            // 视图模式选择
            Picker("", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 320)
            
            Spacer()
            
            Button("关闭") {
                isPresented = false
            }
        }
        .padding()
    }
    
    // MARK: - 对比内容
    
    @ViewBuilder
    private func comparisonContent(size: CGSize) -> some View {
        switch viewMode {
        case .slider:
            sliderComparisonView(size: size)
        case .sideBySide:
            sideBySideView(size: size)
        case .original:
            singleImageView(url: originalURL, label: "原图", size: size)
        case .compressed:
            if let url = compressedURL {
                singleImageView(url: url, label: "压缩后", size: size)
            } else {
                noCompressedImageView
            }
        }
    }
    
    // MARK: - 滑块对比视图
    
    private func sliderComparisonView(size: CGSize) -> some View {
        ZStack {
            // 压缩后图片 (底层)
            if let compressedURL = compressedURL {
                AsyncImage(url: compressedURL) { phase in
                    if case .success(let image) = phase {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            }
            
            // 原图 (通过裁剪显示左半部分)
            AsyncImage(url: originalURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(
                            Rectangle()
                                .size(width: size.width * sliderPosition, height: size.height)
                        )
                }
            }
            
            // 滑块分割线
            Rectangle()
                .fill(Color.white)
                .frame(width: 3)
                .position(x: size.width * sliderPosition, y: size.height / 2)
                .shadow(radius: 2)
            
            // 滑块手柄
            Circle()
                .fill(Color.white)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .foregroundColor(.gray)
                )
                .shadow(radius: 3)
                .position(x: size.width * sliderPosition, y: size.height / 2)
            
            // 标签
            HStack {
                Text("原图")
                    .font(.caption)
                    .padding(6)
                    .background(.ultraThinMaterial)
                    .cornerRadius(4)
                    .padding(10)
                
                Spacer()
                
                if compressedURL != nil {
                    Text("压缩后")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                        .padding(10)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newPosition = value.location.x / size.width
                    sliderPosition = min(max(newPosition, 0.05), 0.95)
                }
        )
    }
    
    // MARK: - 左右对比视图
    
    private func sideBySideView(size: CGSize) -> some View {
        HStack(spacing: 2) {
            // 原图
            VStack {
                Text("原图")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                AsyncImage(url: originalURL) { phase in
                    imagePhaseView(phase)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.1))
                
                Text(formatBytes(originalSize))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 压缩后
            VStack {
                Text("压缩后")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let url = compressedURL {
                    AsyncImage(url: url) { phase in
                        imagePhaseView(phase)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
                } else {
                    noCompressedImageView
                }
                
                if let size = compressedSize {
                    Text(formatBytes(size))
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    // MARK: - 单图视图
    
    private func singleImageView(url: URL, label: String, size: CGSize) -> some View {
        VStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            AsyncImage(url: url) { phase in
                imagePhaseView(phase)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }
    
    private var noCompressedImageView: some View {
        VStack {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("尚未压缩")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func imagePhaseView(_ phase: AsyncImagePhase) -> some View {
        switch phase {
        case .success(let image):
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        case .failure:
            Image(systemName: "photo.badge.exclamationmark")
                .foregroundColor(.secondary)
        case .empty:
            ProgressView()
        @unknown default:
            EmptyView()
        }
    }
    
    // MARK: - 信息栏
    
    private var infoBar: some View {
        HStack(spacing: 30) {
            // 原图信息
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
                Text("原图: \(formatBytes(originalSize))")
                    .font(.caption)
            }
            
            // 压缩后信息
            if let size = compressedSize {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("压缩后: \(formatBytes(size))")
                        .font(.caption)
                }
                
                // 压缩率
                let ratio = Double(originalSize - size) / Double(originalSize) * 100
                Text("节省: \(String(format: "%.1f", ratio))%")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // 文件路径
            Text(originalURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
