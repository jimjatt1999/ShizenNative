```markdown
# Shizen - Japanese Language Learning SRS APP

A macOS app for immersive Japanese learning through audio content, powered by AI analysis and spaced repetition.

## Features

- **Audio Learning**: Import from files, podcasts, YouTube, or recordings
- **AI Analysis**: Grammar/vocabulary breakdowns with Ollama integration
- **SRS System**: Spaced repetition with customizable intervals
- **Content Management**: Podcast/Youtube integration, bulk operations
- **Progress Tracking**: Detailed statistics and review history

## Requirements

- macOS 12.0+
- Swift 5.7+
- Python 3.9+ (for transcription)
- [Ollama server](https://ollama.ai/) running locally

## Installation

```bash
# Clone repository
git clone https://github.com/yourusername/shizen.git
cd shizen

# Install dependencies
brew install python ffmpeg
pip install yt-dlp

# Build and run
swift build
swift run
```

For Xcode development:
```bash
xed .  # Open in Xcode
# Build & Run (⌘R)
```

## Configuration

1. Start Ollama server:
```bash
ollama serve
```

2. Pull required AI model:
```bash
ollama pull deepseek-r1:1.5b
```

## Usage

1. **Import Content** (Files/Podcasts/YouTube/Recordings)
2. **Review Mode** with SRS scheduling
3. **Focus Mode** for intensive practice
4. **Manage** segments and track progress

## License

MIT License - See [LICENSE](LICENSE)
```

Includes both Swift Package Manager and Xcode workflows. The Swift CLI commands assume you have the full toolchain installed via Xcode.
