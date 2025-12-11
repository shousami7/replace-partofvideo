# Video Processing Pipeline - Master Script

## Overview

`master.sh` orchestrates the entire video processing workflow, calling scripts in the correct order with proper error handling and logging.

## Usage

```bash
./master.sh -i <input_video> -s <start_time> -e <end_time> -t <prompt_text> [-f <fps>] [-r]
```

## Required Arguments

- `-i` - Input video file path
- `-s` - Start time (format: `HH:MM:SS` or seconds, e.g., `5` or `00:00:05`)
- `-e` - End time (format: `HH:MM:SS` or seconds, e.g., `10` or `00:00:10`)
- `-t` - Prompt text for AI generation (what you want the AI to do to the frames)

## Optional Arguments

- `-f` - Frames per second (default: `10`)
- `-r` - Run `retry_failed.sh` if there are failed frames

## Example

```bash
./master.sh \
  -i input_video.mp4 \
  -s 5 \
  -e 10 \
  -t "Add a subtitle saying 'Hello World'" \
  -f 10 \
  -r
```

## Workflow Stages

The master script executes the following stages in order:

### Stage 1: Separate Video and Extract Frames
- Calls `separate.sh`
- Splits video into before/during/after segments
- Extracts frames from the target segment at specified FPS
- Creates session directory: `runs/<session_id>/`

### Stage 2: Generate AI-Edited Frames
- Calls `parallel_gen.sh`
- Processes all frames in parallel using Gemini API
- Applies the prompt to each frame
- Tracks failed frames in `tmp/failed_frames.txt`

### Stage 3: Retry Failed Frames (Optional)
- Calls `retry_failed.sh` if `-r` flag is set
- Retries any frames that failed in Stage 2
- Uses same prompt and retry logic

### Stage 4: Concatenate Final Video
- Calls `concatenate.sh`
- Reconstructs video from AI-edited frames
- Concatenates before/edited/after segments
- Outputs final video to `runs/<session_id>/output/final_output.mp4`

## Output

The final output is saved to:
```
runs/<session_id>/output/final_output.mp4
```

A symlink is also created at `runs/latest` pointing to the most recent session.

## Session Directory Structure

```
runs/<session_id>/
├── input/
│   └── <input_video>
├── tmp/
│   ├── frames/              # Original extracted frames
│   ├── before_replace.mp4   # Video before target segment
│   ├── for_replace.mp4      # Target segment
│   ├── after_replace.mp4    # Video after target segment
│   ├── edited_segment.mp4   # Reconstructed from AI frames
│   ├── fps.txt              # FPS value used
│   └── failed_frames.txt    # List of failed frames (if any)
├── output/
│   ├── frames/              # AI-edited frames
│   └── final_output.mp4     # Final concatenated video
└── metadata.json            # Session metadata and status
```

## Error Handling

- The script stops immediately if any stage fails
- Each stage is logged with color-coded output:
  - 🔵 **INFO** - General information
  - 🟢 **SUCCESS** - Stage completed successfully
  - 🟡 **WARNING** - Non-critical issues
  - 🔴 **ERROR** - Critical failures

## Logging

The script provides detailed logging for each stage:
- Stage headers clearly mark each phase
- Success/failure status for each operation
- Frame counts and statistics
- Final metadata display

## Dependencies

Required tools (automatically checked):
- `ffmpeg` - Video processing
- `bc` - Arithmetic calculations
- `jq` - JSON processing
- `curl` - API requests

## Notes

- Each run creates a unique session directory with timestamp
- Session directories are never overwritten
- The `-r` retry flag is optional but recommended for production use
- Failed frames are tracked and can be manually inspected
