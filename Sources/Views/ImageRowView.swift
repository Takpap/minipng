import SwiftUI

/// 图片行视图
struct ImageRowView: View {
    let item: ImageItem
    @ObservedObject var viewModel: CompressionViewModel
    @State private var isHovering = false
    @State private var showComparison = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 缩略图 - 点击预览
            AsyncImage(url: item.url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure:
                    placeholderImage
                case .empty:
                    placeholderImage
                @unknown default:
                    placeholderImage
                }
            }
            .frame(width: 44, height: 44)
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 8) {
                    Text(item.formattedOriginalSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let compressedSize = item.formattedCompressedSize {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(compressedSize)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            // 压缩率
            if let ratio = item.compressionRatio {
                CompressionBadge(ratio: ratio)
            }
            
            // 状态指示
            statusView
            
            // 操作按钮
            if isHovering {
                HStack(spacing: 8) {
                    // 预览对比按钮
                    Button(action: { showComparison = true }) {
                        Image(systemName: "eye")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("预览对比")
                    
                    if case .completed = item.status {
                        Button(action: { viewModel.showInFinder(item) }) {
                            Image(systemName: "folder")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("在 Finder 中显示")
                    }
                    
                    Button(action: { viewModel.removeImage(item) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("移除")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            showComparison = true
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .sheet(isPresented: $showComparison) {
            ComparisonView(
                originalURL: item.url,
                compressedURL: item.outputURL,
                originalSize: item.originalSize,
                compressedSize: item.compressedSize,
                isPresented: $showComparison
            )
        }
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color.secondary.opacity(0.2))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            )
    }
    
    @ViewBuilder
    private var statusView: some View {
        switch item.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.secondary)
        case .compressing:
            ProgressView()
                .scaleEffect(0.6)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .help(item.status.description)
        }
    }
}

/// 压缩率徽章
struct CompressionBadge: View {
    let ratio: Double
    
    var body: some View {
        Text("-\(String(format: "%.0f", ratio))%")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.15))
            .foregroundColor(badgeColor)
            .clipShape(Capsule())
    }
    
    private var badgeColor: Color {
        if ratio >= 60 {
            return .green
        } else if ratio >= 30 {
            return .blue
        } else {
            return .orange
        }
    }
}
