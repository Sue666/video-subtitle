# Video Subtitle Skill

将当前目录中的视频文件转录为字幕（SRT），并可选择将字幕烧录进视频。

## 使用方法

```
/video-subtitle
```

## 执行步骤

### 第一步：检查依赖

检查并安装所需工具：

1. **ffmpeg**
   ```bash
   which ffmpeg || brew install ffmpeg
   ```

2. **Whisper（自动选择最快方案）**

   检测芯片类型，Apple Silicon（M1/M2/M3）优先使用 `mlx-whisper`（GPU 加速，速度约快 5 倍）：

   ```bash
   CHIP=$(uname -m)
   if [ "$CHIP" = "arm64" ]; then
     pip3 show mlx-whisper 2>/dev/null || pip3 install mlx-whisper
     BACKEND="mlx"
   else
     pip3 show openai-whisper 2>/dev/null || pip3 install openai-whisper
     BACKEND="openai"
   fi
   ```

3. **Pillow**（烧录字幕时需要）
   ```bash
   pip3 show Pillow 2>/dev/null || pip3 install Pillow
   ```

### 第二步：找到视频文件

```bash
find . -maxdepth 1 \( -name "*.mp4" -o -name "*.mov" -o -name "*.avi" -o -name "*.mkv" \) | sort
```

如果找到多个视频，询问用户要处理哪个（或全部）。

### 第三步：询问用户需要什么

询问用户：
- 只生成 SRT 字幕文件？
- 还是同时将字幕烧录进视频，生成新 MP4？

### 第四步：语音转录 → SRT

根据第一步检测到的 `$BACKEND` 选择转录方式（第一次运行会下载模型，约 1.4GB）：

**Apple Silicon（mlx-whisper，推荐）：**
```python
import mlx_whisper, json, re

result = mlx_whisper.transcribe(
    "<音频/视频文件路径>",
    path_or_hf_repo="mlx-community/whisper-medium-mlx"
)

def to_srt_time(s):
    h = int(s // 3600); m = int((s % 3600) // 60)
    sec = int(s % 60); ms = int((s % 1) * 1000)
    return f"{h:02d}:{m:02d}:{sec:02d},{ms:03d}"

lines = []
for i, seg in enumerate(result["segments"], 1):
    lines += [str(i), f"{to_srt_time(seg['start'])} --> {to_srt_time(seg['end'])}", seg['text'].strip(), ""]

srt_path = "<输出路径>.srt"
with open(srt_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))
print(f"字幕已生成：{srt_path}")
```

**Intel Mac（openai-whisper）：**
```bash
WHISPER=$(which whisper 2>/dev/null || find ~/Library/Python -name whisper -type f 2>/dev/null | head -1)
"$WHISPER" "<视频文件路径>" --model medium --output_format srt --output_dir .
```

转录完成后，SRT 文件与视频同名，扩展名为 `.srt`。

### 第五步（可选）：字幕烧录进视频

如果用户需要烧录字幕，将以下脚本保存为 `/tmp/burn_subs.py` 并执行：

```python
import re, os, subprocess
from PIL import Image, ImageDraw, ImageFont

def burn_subtitles(video_in, srt_path, video_out):
    result = subprocess.run(
        ["ffprobe", "-v", "quiet", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0", video_in],
        capture_output=True, text=True
    )
    w, h = map(int, result.stdout.strip().split(","))

    font_candidates = [
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/PingFang.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
    ]
    font_path = next((f for f in font_candidates if os.path.exists(f)), None)
    if not font_path:
        raise RuntimeError("未找到支持中文的字体")

    font_size = max(28, h // 25)

    def to_sec(t):
        parts = t.strip().split(":")
        s, ms = parts[2].split(",")
        return int(parts[0])*3600 + int(parts[1])*60 + int(s) + int(ms)/1000

    with open(srt_path, encoding="utf-8") as f:
        content = f.read()

    entries = []
    for block in re.split(r'\n\n+', content.strip()):
        lines = block.strip().split('\n')
        if len(lines) < 3:
            continue
        m = re.match(r'(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})', lines[1])
        if not m:
            continue
        entries.append((to_sec(m.group(1)), to_sec(m.group(2)), ' '.join(lines[2:])))

    tmp_dir = "/tmp/sub_pngs"
    os.makedirs(tmp_dir, exist_ok=True)
    font = ImageFont.truetype(font_path, font_size)
    PADDING = 16

    cmd = ["ffmpeg", "-y", "-i", video_in]
    png_data = []

    for i, (start, end, text) in enumerate(entries):
        dummy = Image.new("RGBA", (1, 1))
        bbox = ImageDraw.Draw(dummy).textbbox((0, 0), text, font=font)
        tw = bbox[2] - bbox[0] + PADDING * 2
        th = bbox[3] - bbox[1] + PADDING * 2

        img = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        for dx, dy in [(-2,-2),(-2,2),(2,-2),(2,2),(0,-2),(0,2),(-2,0),(2,0)]:
            draw.text((PADDING+dx, PADDING+dy), text, font=font, fill=(0,0,0,200))
        draw.text((PADDING, PADDING), text, font=font, fill=(255,255,255,255))

        path = f"{tmp_dir}/sub_{i:04d}.png"
        img.save(path)
        png_data.append((start, end, path, tw, th))
        cmd += ["-i", path]

    parts = []
    prev = "0:v"
    for i, (start, end, _, tw, th) in enumerate(png_data):
        out = f"v{i}"
        parts.append(
            f"[{prev}][{i+1}:v]overlay=(W-{tw})/2:H-{th}-30"
            f":enable='between(t,{start},{end})'[{out}]"
        )
        prev = out

    cmd += ["-filter_complex", ";".join(parts)]
    cmd += ["-map", f"[{prev}]", "-map", "0:a"]
    cmd += ["-c:v", "libx264", "-crf", "18", "-preset", "fast", "-c:a", "copy", video_out]
    subprocess.run(cmd, check=True)
    print(f"完成：{video_out}")

# 示例（由 Claude 替换实际文件名）
burn_subtitles("VIDEO_IN", "SRT_PATH", "VIDEO_OUT")
```

### 第六步：汇报结果

完成后告知用户生成的文件路径和大小。
