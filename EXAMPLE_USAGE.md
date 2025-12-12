# Complete Workflow Example

This document provides a complete example of using the video processing pipeline with `master.sh`.

## Quick Start

```bash
# Basic usage
./master.sh \
  -i input_video.mp4 \
  -s 5 \
  -e 10 \
  -t "Add a subtitle saying 'Hello World'"

# With custom FPS and retry enabled
./master.sh \
  -i input_video.mp4 \
  -s 5 \
  -e 10 \
  -t "Add a subtitle saying 'Hello World'" \
  -f 15 \
  -r
```

## Example Session Output

After running the command, you'll see output like this:

```
[INFO] Starting video processing workflow
[INFO] Session ID: 20251211_164951
[INFO] Session directory: /Users/shousami/replace-partofvideo/runs/20251211_164951
[INFO] Input video: input_video.mp4
[INFO] Time range: 5 to 10
[INFO] FPS: 10
[INFO] Prompt: Add a subtitle saying 'Hello World'
[INFO] Retry failed frames: false

========================================
STAGE: 1/4 - Separating video and extracting frames
========================================
Session directory: /Users/shousami/replace-partofvideo/runs/20251211_164951
fps: 10
Time range: 5 to 10 (duration: 5s)
✓ Session initialized: /Users/shousami/replace-partofvideo/runs/20251211_164951
✓ Extracted 50 frames

[SUCCESS] Video separation and frame extraction completed
[INFO] Extracted 50 frames

========================================
STAGE: 2/4 - Generating AI-edited frames
========================================
✓ Frame 00001 completed
✓ Frame 00002 completed
...
✓ Frame 00050 completed
✓ Updated metadata.json

[SUCCESS] AI frame generation completed
[SUCCESS] No failed frames detected

========================================
STAGE: 4/4 - Concatenating final video
========================================
Using fps: 10
Generating edited segment from frames...
Segments detected: before=true, after=true
Concatenating all three segments...
✓ Final output created: /Users/shousami/replace-partofvideo/runs/20251211_164951/output/final_output.mp4
✓ Updated metadata.json

[SUCCESS] Final video concatenation completed

========================================
WORKFLOW COMPLETED SUCCESSFULLY
========================================
[SUCCESS] Final output: /Users/shousami/replace-partofvideo/runs/20251211_164951/output/final_output.mp4
[INFO] Session directory: /Users/shousami/replace-partofvideo/runs/20251211_164951
[INFO] Metadata:
{
  "session_id": "20251211_164951",
  "created_at": "2025-12-11T07:49:51+0000",
  "input_video": "input_video.mp4",
  "start_time": "5",
  "end_time": "10",
  "fps": 10,
  "prompt": "Add a subtitle saying 'Hello World'",
  "model_version": "gemini-3-pro-image-preview",
  "status": "completed",
  "total_frames": 50,
  "failed_frames": []
}
[INFO] Latest run symlink: /Users/shousami/replace-partofvideo/runs/latest

[SUCCESS] All done! 🎉
```

## Generated Directory Structure

```
runs/20251211_164951/
├── input/
│   └── input_video.mp4           # Copy of original input
├── tmp/
│   ├── frames/                   # 50 original extracted frames
│   │   ├── frame_00001.png
│   │   ├── frame_00002.png
│   │   └── ...
│   ├── before_replace.mp4        # Video before 5s mark
│   ├── for_replace.mp4           # Video from 5s to 10s
│   ├── after_replace.mp4         # Video after 10s mark
│   ├── edited_segment.mp4        # Reconstructed from AI frames
│   ├── fps.txt                   # Contains: 10
│   └── concat_list.txt           # FFmpeg concat list
├── output/
│   ├── frames/                   # 50 AI-edited frames
│   │   ├── frame_00001.png
│   │   ├── frame_00002.png
│   │   └── ...
│   └── final_output.mp4          # ⭐ FINAL VIDEO
└── metadata.json                 # Session metadata
```

## Accessing Results

```bash
# Watch the final video
open runs/latest/output/final_output.mp4

# Or use the full path
open runs/20251211_164951/output/final_output.mp4

# View metadata
cat runs/latest/metadata.json | jq '.'

# Check for failed frames
jq '.failed_frames' runs/latest/metadata.json
```

## Handling Failed Frames

If some frames fail during generation:

```bash
# Run with retry flag
./master.sh \
  -i input_video.mp4 \
  -s 5 \
  -e 10 \
  -t "Add a subtitle saying 'Hello World'" \
  -r

# Or manually retry later
./retry_failed.sh -t "Add a subtitle saying 'Hello World'"
```

## Advanced Examples

### High FPS Processing
```bash
./master.sh \
  -i input_video.mp4 \
  -s 0 \
  -e 3 \
  -t "Make it look like a comic book" \
  -f 30 \
  -r
```

### Time Format Options
```bash
# Using seconds
./master.sh -i video.mp4 -s 5 -e 10 -t "Add glow effect"

# Using HH:MM:SS format
./master.sh -i video.mp4 -s 00:00:05 -e 00:00:10 -t "Add glow effect"

# Using decimal seconds
./master.sh -i video.mp4 -s 5.5 -e 10.25 -t "Add glow effect"
```

### Complex Prompts
```bash
./master.sh \
  -i input_video.mp4 \
  -s 5 \
  -e 10 \
  -t "Add a subtitle saying 'BREAKING NEWS' in red bold text at the top. Add a news ticker at the bottom showing 'Live from New York'. Make the background slightly darker."
```

## Troubleshooting

### Check Session Status
```bash
# View current status
jq '.status' runs/latest/metadata.json

# Possible values:
# - "frames_extracted"  → Stage 1 complete
# - "frames_generated"  → Stage 2 complete
# - "completed"         → All stages complete
```

### View Failed Frames
```bash
# List failed frames
jq '.failed_frames[]' runs/latest/metadata.json

# Count failed frames
jq '.failed_frames | length' runs/latest/metadata.json
```

### Manual Recovery
```bash
# If master.sh fails mid-way, you can resume manually:

# 1. Find the session directory
ls -lt runs/

# 2. Continue from where it stopped
cd runs/20251211_164951

# 3. Run remaining stages manually
../../parallel_gen.sh -d . -t "your prompt" -n 50
../../concatenate.sh -d .
```

## Performance Tips

1. **Lower FPS for faster processing**: Use `-f 5` or `-f 8` for quicker results
2. **Enable retry**: Always use `-r` flag for production to handle transient failures
3. **Shorter segments**: Process 3-5 second segments for best results
4. **Monitor rate limits**: The pipeline uses `MAX_JOBS=6` to avoid API rate limiting

## Next Steps

- View the final video: `open runs/latest/output/final_output.mp4`
- Check metadata: `cat runs/latest/metadata.json | jq '.'`
- Compare frames: `open runs/latest/tmp/frames/frame_00001.png` vs `open runs/latest/output/frames/frame_00001.png`
- Archive session: `tar -czf session.tar.gz runs/20251211_164951/`
