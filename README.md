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

# Core Workflows Guide

## 1. Audio Import Methods

### 🎙️ Record Directly
1. Go to Upload → Record tab
2. Click microphone icon to start recording
3. Click again to stop - auto-saves to review queue

###  File Upload
1. Drag-drop audio files into Upload tab
2. Supported formats: MP3, WAV, M4A, AAC
3. Files get processed into segments automatically

### Podcasts
1. Search Japanese podcasts in Podcast tab
   - Pre-loaded with educational podcasts
2. Browse episodes → Download audio
3. Episodes auto-import for transcription

###  YouTube
1. Paste YouTube URL in YouTube tab
2. App extracts audio → converts to MP3
3. Processes like local files

## 2. Transcription & Segments

After audio import:
- Automatic Whisper transcription creates text segments
- Segments show audio waveform + text
- Tap eye icon to reveal/hide transcript
- Edit segment boundaries in Manage tab

## 3. SRS Practice System

Spaced Repetition:
1. Cards appear in Review queue based on:
   - New cards (38/day default)
   - Due cards (algorithm-based)
2. Four response options:
   - Again (1m) | Hard (10m) | Good (4d) | Easy (7d)
3. Practice in:
   - **Normal Mode**: Mixed cards feed
   - **Focus Mode**: Intensive single-source sessions

## 4. AI Analysis Tools

For any Japanese text segment:
1. Click brain icon to activate analysis
2. AI returns:
   - English translation
   - Word-by-word breakdown (reading/meaning)
   - Grammar explanations
   - Cultural context notes
3. Powered by Ollama's `deepseek-r1:1.5b` model

## Pro Tips
- Bulk tag segments as "Hidden from SRS" in Manage tab
- Adjust playback speed during reviews (0.75x-2x)
- Export SRS stats to CSV for tracking
- Use "Hard" tag to isolate difficult segments

## License

MIT License - See [LICENSE](LICENSE)
```

Includes both Swift Package Manager and Xcode workflows. The Swift CLI commands assume you have the full toolchain installed via Xcode.
