# Shizen - Japanese Language Learning Assistant

![App Screenshot](screenshot.png) *<!-- Add actual screenshot path -->*

A macOS app for immersive Japanese learning through audio content, powered by AI analysis and spaced repetition.

## Features

- **Multi-source Audio Import**
  - Record directly in-app
  - Upload local files (MP3/WAV/M4A/AAC)
  - Download podcast episodes
  - Extract audio from YouTube videos

- **Smart Learning System**
  - Automatic Whisper transcription
  - AI-powered text analysis (Ollama integration)
  - Customizable Spaced Repetition (SRS)
  - Focus Mode for intensive practice

- **Content Management**
  - Bulk segment operations
  - Duplicate detection
  - Playback speed control (0.75x-2x)
  - Detailed progress statistics

## Requirements

- **System**
  - macOS 12 Monterey or newer
  - 8GB RAM minimum (16GB recommended for AI features)

- **Dependencies**
  - [Python 3.9+](https://www.python.org/)
  - [FFmpeg](https://ffmpeg.org/)
  - [Ollama](https://ollama.ai/) (running locally)
  - [yt-dlp](https://github.com/yt-dlp/yt-dlp)

## Installation

### Swift Package Manager

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

Xcode Development
	1.	Open project:

xed .


	2.	Build:
	•	⌘B or Product > Build
	3.	Run:
	•	⌘R or Product > Run

Configuration
	1.	Start Ollama server in terminal:

ollama serve


	2.	Download AI model:

ollama pull deepseek-r1:1.5b


	3.	Enable required permissions:
	•	Microphone access (System Preferences > Security)
	•	File system access (when first importing audio)

Usage Guide

1. Importing Audio Content

🎙️ Record Directly
	1.	Navigate to Upload → Record tab
	2.	Click microphone icon to start/stop recording
	3.	Recordings auto-save for processing

📂 File Upload
	1.	Drag-drop audio files into Upload tab
	2.	Supported formats: MP3, WAV, M4A, AAC
	3.	Files process automatically (check Notifications)

🎧 Podcasts
	1.	Search Japanese podcasts in Podcast tab
	2.	Browse episodes from educational channels:
	•	JapanesePod101
	•	News in Slow Japanese
	•	NHK World Radio
	3.	Download episodes → Auto-process to segments

▶️ YouTube
	1.	Paste YouTube URL in YouTube tab
	2.	App handles:
	•	Audio extraction
	•	MP3 conversion
	•	Automatic segmentation

2. Working with Segments
	•	Automatic Processing:
	•	Whisper transcription creates text segments
	•	Visual waveform display
	•	Auto-generated timestamps
	•	Segment Management:
	•	Toggle transcripts with 👁️ icon
	•	Adjust boundaries in Manage tab
	•	Bulk tag/delete segments
	•	Mark duplicates/hidden from SRS

3. Spaced Repetition (SRS)

Review System:
	•	Cards queue based on:
	•	New cards (38/day default)
	•	Algorithm-scheduled reviews
	•	Response options:
	•	Again (1m) | Hard (10m) | Good (4d) | Easy (7d)

Practice Modes:
	•	Normal Mode: Mixed card feed
	•	Focus Mode:
	•	Single-source intensive sessions
	•	Save/Restore progress
	•	Session statistics

4. AI-Powered Analysis

Text Breakdown:
	1.	Click 🧠 icon on any segment
	2.	Get instant analysis:
	•	English translation
	•	Word-by-word readings/meanings
	•	Grammar explanations
	•	Cultural context notes

Customization:
	•	Adjust AI temperature in Settings
	•	Modify analysis prompts
	•	Cache management for responses

Advanced Features
	•	Playback Controls:
	•	Speed adjustment (0.75x-2x)
	•	Loop segments
	•	Waveform scrubbing
	•	Statistics:
	•	Review history timeline
	•	Accuracy heatmaps
	•	Retention curves
	•	CSV export
	•	Custom SRS:
	•	Modify learning steps
	•	Adjust ease factors
	•	Set daily limits
	•	Backup/restore progress

Troubleshooting

Common Issues:
	•	Ollama Connection Failed:
	•	Verify ollama serve is running
	•	Check firewall settings
	•	Transcription Failures:
	•	Ensure Python/FFmpeg installed
	•	Verify audio file permissions
	•	Playback Issues:
	•	Convert files to MP3 format
	•	Check system audio output

License

MIT License - See LICENSE file for details

Contributing:
We welcome contributions! Please see CONTRIBUTING.md for guidelines.

Support:
For issues and feature requests, please use the GitHub Issues tracker.

