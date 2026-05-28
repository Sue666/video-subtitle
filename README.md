# video-subtitle

A Claude Code skill that transcribes video audio to SRT subtitles and optionally burns them into the video.

## Features

- 🎙️ Transcribes speech from video files using OpenAI Whisper
- 📝 Generates `.srt` subtitle files
- 🎬 Burns subtitles into video (hardcoded), producing a new MP4
- 🇨🇳 Supports Chinese and mixed Chinese/English content
- 🔧 Auto-installs dependencies (ffmpeg, whisper, Pillow)

## Requirements

- macOS with [Homebrew](https://brew.sh)
- Python 3
- Claude Code

## Installation

Clone this repo into your Claude Code commands directory:

```bash
git clone https://github.com/Sue666/video-subtitle.git ~/.claude/commands/video-subtitle
cp ~/.claude/commands/video-subtitle/.claude/commands/video-subtitle.md ~/.claude/commands/video-subtitle.md
```

Or install with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/Sue666/video-subtitle/main/install.sh | bash
```

## Usage

Navigate to a directory containing video files, then run:

```
/video-subtitle
```

Claude will:
1. Check and install dependencies automatically
2. Find video files in the current directory
3. Transcribe audio using Whisper (medium model, ~1.4GB download on first run)
4. Generate a `.srt` subtitle file
5. Ask if you want to burn the subtitles into the video

## Supported Formats

Input: `.mp4`, `.mov`, `.avi`, `.mkv`

Output: `.srt` subtitle file, and optionally a new `.mp4` with burned-in subtitles
