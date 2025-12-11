# metadata.json Structure

The `metadata.json` file is automatically created and updated throughout the video processing pipeline. It contains all session information and is located at `runs/<session_id>/metadata.json`.

## Complete Structure

```json
{
  "session_id": "20251211_164545",
  "created_at": "2025-12-11T07:45:45+0000",
  "input_video": "input_video.mp4",
  "start_time": "5",
  "end_time": "10",
  "fps": 10,
  "prompt": "Add a subtitle saying 'Hello World'",
  "model_version": "gemini-2.5-flash-image",
  "status": "completed",
  "total_frames": 50,
  "failed_frames": []
}
```

## Field Descriptions

| Field | Type | Description | Set By |
|-------|------|-------------|--------|
| `session_id` | string | Unique session identifier (timestamp format) | `separate.sh` |
| `created_at` | string | ISO 8601 timestamp (UTC) | `separate.sh` |
| `input_video` | string | Original input video filename | `separate.sh` |
| `start_time` | string | Start time of target segment | `separate.sh` |
| `end_time` | string | End time of target segment | `separate.sh` |
| `fps` | number | Frames per second used for extraction | `separate.sh` |
| `prompt` | string | AI generation prompt text | `parallel_gen.sh` |
| `model_version` | string | Gemini model used for generation | `separate.sh` |
| `status` | string | Current pipeline status | Updated by each script |
| `total_frames` | number | Total number of frames extracted | `separate.sh` |
| `failed_frames` | array | List of frame IDs that failed generation | `parallel_gen.sh` |

## Status Values

The `status` field is updated as the pipeline progresses:

1. **`frames_extracted`** - Set by `separate.sh` after frame extraction
2. **`frames_generated`** - Set by `parallel_gen.sh` after AI generation
3. **`completed`** - Set by `concatenate.sh` after final video creation

## Failed Frames Format

If frames fail during AI generation, they are tracked in the `failed_frames` array:

```json
{
  "failed_frames": ["00001", "00023", "00045"]
}
```

Each entry is a zero-padded 5-digit frame ID (e.g., `00001`, `00023`).

## Example Usage

### Reading metadata in bash:
```bash
# Get session status
status=$(jq -r '.status' runs/latest/metadata.json)

# Get failed frame count
failed_count=$(jq '.failed_frames | length' runs/latest/metadata.json)

# Get all metadata
jq '.' runs/latest/metadata.json
```

### Reading metadata in Python:
```python
import json

with open('runs/latest/metadata.json') as f:
    metadata = json.load(f)
    
print(f"Session: {metadata['session_id']}")
print(f"Status: {metadata['status']}")
print(f"Failed frames: {len(metadata['failed_frames'])}")
```

## Timestamps

All timestamps use ISO 8601 format in UTC:
- Format: `YYYY-MM-DDTHH:MM:SS+0000`
- Example: `2025-12-11T07:45:45+0000`

This ensures consistent, sortable, and timezone-aware timestamps across all sessions.
