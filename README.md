# MiniPNG

An efficient image compression tool supporting PNG, JPEG, WebP, and GIF formats.

![MiniPNG Screenshot](screenshot.png)

## Features

- 🖼️ **Multi-format Support** - PNG, JPEG, WebP, GIF
- 🚀 **High Compression Ratio** - Powered by industry-leading open-source compression engines
- ⚡ **Concurrent Compression** - Multi-threaded batch processing
- 🎯 **Drag & Drop** - Simply drag files or folders to compress
- 🔍 **Preview Comparison** - Compare before and after compression
- 💾 **Flexible Output** - Replace source files or generate new ones

## Compression Engines

| Format | Engine | Description |
|--------|--------|-------------|
| PNG | pngquant + oxipng | Lossy quantization + lossless optimization |
| JPEG | mozjpeg | Mozilla's improved JPEG encoder |
| WebP | cwebp | Google WebP encoder |
| GIF | gifsicle | GIF optimization tool |

## Installation

### Download
Download the DMG file for your architecture from the [Releases](../../releases) page:
- `MiniPNG-x.x.x-arm64.dmg` - Apple Silicon (M1/M2/M3)
- `MiniPNG-x.x.x-x86_64.dmg` - Intel

### Build from Source
```bash
# Install dependencies
brew install pngquant mozjpeg gifsicle webp oxipng

# Build
swift build -c release

# Package
./scripts/build-app.sh
```

## Usage

1. Drag images or folders to the window
2. Select compression quality (High Compression / Balanced / High Quality)
3. Click "Start Compression" or press `⌘⏎`

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open files |
| `⌘⏎` | Start compression |
| `⌘⌫` | Clear list |

## System Requirements

- macOS 13.0 or later
- Apple Silicon or Intel processor

## License

MIT License
