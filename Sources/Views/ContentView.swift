import SwiftUI

/// 主视图
struct ContentView: View {
    @ObservedObject var viewModel: CompressionViewModel
    @State private var isDragOver = false
    
    init(viewModel: CompressionViewModel? = nil) {
        self._viewModel = ObservedObject(wrappedValue: viewModel ?? CompressionViewModel())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            toolbarView
            
            Divider()
            
            // 主内容区域
            if viewModel.images.isEmpty {
                dropZoneView
            } else {
                imageListView
            }
            
            // 底部状态栏
            if !viewModel.images.isEmpty {
                Divider()
                statusBarView
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - 工具栏
    
    private var toolbarView: some View {
        HStack(spacing: 16) {
            // Logo 和标题
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.right.and.arrow.up.left.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.linearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                
                Text("MiniPNG")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            // 质量选择
            Picker("", selection: $viewModel.quality) {
                ForEach(CompressionService.Quality.allCases, id: \.self) { quality in
                    Text(quality.displayName).tag(quality)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 200)
            
            Divider()
                .frame(height: 20)
            
            // 替换源文件开关
            Toggle(isOn: $viewModel.replaceOriginal) {
                Text("替换源文件")
                    .font(.caption)
                    .foregroundColor(viewModel.replaceOriginal ? .orange : .secondary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("开启后将直接覆盖原文件，请谨慎使用")
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 12) {
                Button(action: { viewModel.openFilePicker() }) {
                    Label("添加", systemImage: "plus")
                }
                
                if !viewModel.images.isEmpty {
                    Button(action: { viewModel.clearAll() }) {
                        Label("清空", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                    
                    Button(action: { viewModel.compressAll() }) {
                        Label(
                            viewModel.isCompressing ? "压缩中..." : "开始压缩",
                            systemImage: viewModel.isCompressing ? "hourglass" : "play.fill"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isCompressing)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - 拖拽区域
    
    private var dropZoneView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                // 背景发光效果
                if isDragOver {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(maxWidth: 520, maxHeight: 320)
                        .blur(radius: 20)
                }
                
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        style: StrokeStyle(lineWidth: isDragOver ? 3 : 2, dash: [10])
                    )
                    .foregroundColor(isDragOver ? .accentColor : .secondary.opacity(0.3))
                    .frame(maxWidth: 500, maxHeight: 300)
                    .scaleEffect(isDragOver ? 1.02 : 1.0)
                
                VStack(spacing: 16) {
                    Image(systemName: isDragOver ? "arrow.down.circle.fill" : "arrow.down.doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                        .scaleEffect(isDragOver ? 1.2 : 1.0)
                    
                    Text(isDragOver ? "松开以添加图片" : "拖拽图片或文件夹到这里")
                        .font(.title2)
                        .foregroundColor(isDragOver ? .accentColor : .secondary)
                    
                    Text("支持 PNG、JPG、WebP、GIF 格式")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    
                    if !isDragOver {
                        Button("或点击选择文件") {
                            viewModel.openFilePicker()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // 快捷键提示
                    Text("⌘O 打开文件 · ⌘⏎ 开始压缩")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.5))
                        .padding(.top, 8)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragOver)
            
            Spacer()
        }
        .padding(40)
    }
    
    // MARK: - 图片列表
    
    private var imageListView: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(viewModel.images) { item in
                    ImageRowView(item: item, viewModel: viewModel)
                }
            }
            .padding()
        }
    }
    
    // MARK: - 状态栏
    
    private var statusBarView: some View {
        HStack {
            // 统计信息
            HStack(spacing: 20) {
                Label("\(viewModel.totalCount) 张图片", systemImage: "photo.stack")
                
                if viewModel.completedCount > 0 {
                    Label("\(viewModel.completedCount) 已完成", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("节省 \(viewModel.formattedTotalSaved)", systemImage: "arrow.down.circle.fill")
                        .foregroundColor(.blue)
                    
                    if viewModel.averageCompressionRatio > 0 {
                        Text("平均压缩 \(String(format: "%.1f", viewModel.averageCompressionRatio))%")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Spacer()
            
            // 进度指示
            if viewModel.isCompressing {
                ProgressView()
                    .scaleEffect(0.7)
                Text("处理中 \(viewModel.completedCount)/\(viewModel.totalCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - 拖拽处理
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                
                Task { @MainActor in
                    viewModel.addImages(urls: [url])
                }
            }
        }
    }
}
