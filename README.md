# MiniPNG

高效的图片压缩工具，支持 PNG、JPEG、WebP、GIF 格式。

![MiniPNG Screenshot](screenshot.png)

## 功能特性

- 🖼️ **多格式支持** - PNG、JPEG、WebP、GIF
- 🚀 **高压缩率** - 使用业界顶级开源压缩引擎
- ⚡ **并发压缩** - 多线程批量处理
- 🎯 **拖拽操作** - 拖拽文件或文件夹即可压缩
- 🔍 **对比预览** - 压缩前后效果对比
- 💾 **灵活输出** - 支持替换源文件或生成新文件

## 压缩引擎

| 格式 | 引擎 | 说明 |
|------|------|------|
| PNG | pngquant + oxipng | 有损量化 + 无损优化 |
| JPEG | mozjpeg | Mozilla 改进的 JPEG 编码器 |
| WebP | cwebp | Google WebP 编码器 |
| GIF | gifsicle | GIF 优化工具 |

## 安装

### 下载安装
从 [Releases](../../releases) 页面下载对应架构的 DMG 文件：
- `MiniPNG-x.x.x-arm64.dmg` - Apple Silicon (M1/M2/M3)
- `MiniPNG-x.x.x-x86_64.dmg` - Intel

### 从源码构建
```bash
# 安装依赖
brew install pngquant mozjpeg gifsicle webp oxipng

# 构建
swift build -c release

# 打包
./scripts/build-app.sh
```

## 使用方法

1. 拖拽图片或文件夹到窗口
2. 选择压缩质量（高压缩 / 均衡 / 高质量）
3. 点击「开始压缩」或按 `⌘⏎`

### 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘O` | 打开文件 |
| `⌘⏎` | 开始压缩 |
| `⌘⌫` | 清空列表 |

## 系统要求

- macOS 13.0 或更高版本
- Apple Silicon 或 Intel 处理器

## 开源协议

MIT License
