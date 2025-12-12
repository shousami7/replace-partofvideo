#!/bin/bash

# Dependency validation
command -v ffmpeg >/dev/null 2>&1 || { echo "Error: ffmpeg not found. Please install ffmpeg."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc not found. Please install bc."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found. Please install jq."; exit 1; }

# Robust shell flags
set -euo pipefail

# Convert inputs such as "HH:MM:SS", "MM:SS", or plain seconds (including decimals) to seconds
parse_time_to_seconds() {
    local time_input="$1"
    if [[ "$time_input" == *:* ]]; then
        IFS=':' read -r h m s <<< "$time_input"
        h=${h:-0}
        m=${m:-0}
        s=${s:-0}
        echo "$(echo "$h * 3600 + $m * 60 + $s" | bc -l)"
    else
        if ! [[ "$time_input" =~ ^([0-9]+(\.[0-9]+)?|\.[0-9]+)$ ]]; then
            echo "Error: Invalid time format '$time_input'. Use HH:MM:SS or seconds (optionally decimal)." >&2
            exit 1
        fi
        echo "$time_input"
    fi
}

# Format decimal seconds for ffmpeg (adds leading zero and limits precision)
format_seconds() {
    local value="$1"
    awk -v val="$value" 'BEGIN { printf "%.6f", val }'
}

# Parse command-line arguments
session_dir=""
while getopts "i:s:e:f:d:" opt; do
    case $opt in
        i)
            input=$OPTARG;;
        s)
            start=$OPTARG;;
        e)
            end=$OPTARG;;
        f)
            fps=$OPTARG;;
        d)
            session_dir=$OPTARG;;
        \?)
            echo "Usage: $0 -i <input mp4 file> -s <start time> -e <end time> [-f <fps>] [-d <session_dir>]"
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

if [ -z "$input" ] || [ -z "$start" ] || [ -z "$end" ]; then
    echo "Usage: $0 -i <input mp4 file> -s <start time> -e <end time> [-f <fps>] [-d <session_dir>]"
    exit 1
fi

# Default fps to 10 if not provided
if [ -z "$fps" ]; then
    fps=10
fi

# Generate session directory if not provided
if [ -z "$session_dir" ]; then
    session_id=$(date +%Y%m%d_%H%M%S)
    session_dir="$PWD/runs/$session_id"
fi

# Create session directory structure
mkdir -p "$session_dir"/{input,tmp/frames,output/frames}

# Copy input video to session directory
input_basename=$(basename "$input")
cp "$input" "$session_dir/input/$input_basename"

echo "Session directory: $session_dir"
echo "fps: $fps"

# Convert start and end times to seconds
start_sec=$(parse_time_to_seconds "$start")
end_sec=$(parse_time_to_seconds "$end")

# Calculate duration in seconds (supports decimals)
duration=$(echo "$end_sec - $start_sec" | bc -l)

# Validate duration
if [ "$(echo "$duration > 0" | bc -l)" -ne 1 ]; then
    echo "Error: Invalid time range. Duration must be positive (end > start)"
    echo "  start: $start ($start_sec seconds)"
    echo "  end: $end ($end_sec seconds)"
    echo "  duration: $duration seconds"
    exit 1
fi

duration_fmt=$(format_seconds "$duration")
echo "Time range: $start to $end (duration: ${duration_fmt}s)"

# Split video into three parts
# Use re-encoding to prevent video stream loss issues
start_sec_fmt=$(format_seconds "$start_sec")
end_sec_fmt=$(format_seconds "$end_sec")
ffmpeg -i "$input" -to "$start_sec_fmt" -c:v libx264 -c:a aac -strict -2 "$session_dir/tmp/before_replace.mp4"
ffmpeg -i "$input" -ss "$start_sec_fmt" -t "$duration_fmt" -c:v libx264 -c:a aac -strict -2 "$session_dir/tmp/for_replace.mp4"
ffmpeg -i "$input" -ss "$end_sec_fmt" -c:v libx264 -c:a aac -strict -2 "$session_dir/tmp/after_replace.mp4"

# Extract frames at specified fps and save fps value for concatenation
ffmpeg -i "$session_dir/tmp/for_replace.mp4" -vf "fps=$fps" "$session_dir/tmp/frames/frame_%05d.png"

# Save fps to file for downstream scripts
echo "$fps" > "$session_dir/tmp/fps.txt"

# Count total frames
total_frames=$(find "$session_dir/tmp/frames" -name "frame_*.png" | wc -l | tr -d ' ')

# Initialize metadata.json
jq -n \
    --arg session_id "$(basename "$session_dir")" \
    --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%S%z)" \
    --arg input_video "$input_basename" \
    --arg start "$start" \
    --arg end "$end" \
    --argjson fps "$fps" \
    --argjson total_frames "$total_frames" \
    --arg model_version "gemini-3-pro-image-preview" \
    '{
        session_id: $session_id,
        created_at: $created_at,
        input_video: $input_video,
        start_time: $start,
        end_time: $end,
        fps: $fps,
        prompt: "",
        model_version: $model_version,
        status: "frames_extracted",
        total_frames: $total_frames,
        failed_frames: []
    }' > "$session_dir/metadata.json"

echo "✓ Session initialized: $session_dir"
echo "✓ Extracted $total_frames frames"
