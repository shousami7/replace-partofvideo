#!/bin/bash

# Dependency validation
command -v ffmpeg >/dev/null 2>&1 || { echo "Error: ffmpeg not found. Please install ffmpeg."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc not found. Please install bc."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found. Please install jq."; exit 1; }

# Robust shell flags
set -euo pipefail

# Parse command-line arguments
session_dir=""
while getopts "d:" opt; do
    case $opt in
        d)
            session_dir=$OPTARG;;
        \?)
            echo "Usage: $0 -d <session_dir>"
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

# Validate session directory is provided
if [ -z "$session_dir" ]; then
    echo "Error: Session directory (-d) is required"
    echo "Usage: $0 -d <session_dir>"
    exit 1
fi

# Load fps from saved file
if [ -f "$session_dir/tmp/fps.txt" ]; then
    fps=$(cat "$session_dir/tmp/fps.txt")
else
    fps=10
fi

# Validate fps (must be numeric)
if ! [[ "$fps" =~ ^[0-9]+$ ]]; then
    fps=10
fi

echo "Using fps: $fps"

# Step 1: Generate edited_segment.mp4 from AI-generated frames
# Frames are in output/frames/ and may not be sequential (parallel processing)
echo "Generating edited segment from frames..."

# Create temp directory for sequential symlinks
seq_dir="$session_dir/tmp/seq_frames"
rm -rf "$seq_dir"
mkdir -p "$seq_dir"

# Get all generated frames sorted numerically and create sequential symlinks
frame_count=0
for frame in $(ls -1 "$session_dir/output/frames"/frame_*.png 2>/dev/null | sort -V); do
    frame_count=$((frame_count + 1))
    ln -sf "$frame" "$seq_dir/$(printf "frame_%05d.png" $frame_count)"
done

if [ "$frame_count" -eq 0 ]; then
    echo "Error: No frames found in $session_dir/output/frames/"
    exit 1
fi

echo "Found $frame_count frames, creating video..."

ffmpeg -y \
  -framerate "$fps" \
  -start_number 1 \
  -i "$seq_dir/frame_%05d.png" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -r "$fps" \
  "$session_dir/tmp/edited_segment.mp4"

if [ ! -f "$session_dir/tmp/edited_segment.mp4" ]; then
    echo "Error: Failed to generate edited_segment.mp4"
    exit 1
fi

# Step 2: Determine which segments exist
has_before=false
has_after=false

if [ -f "$session_dir/tmp/before_replace.mp4" ] && [ -s "$session_dir/tmp/before_replace.mp4" ]; then
    # Check if file has actual video content (duration > 0)
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$session_dir/tmp/before_replace.mp4" 2>/dev/null)
    if [ -n "$duration" ] && (( $(echo "$duration > 0" | bc -l) )); then
        has_before=true
    fi
fi

if [ -f "$session_dir/tmp/after_replace.mp4" ] && [ -s "$session_dir/tmp/after_replace.mp4" ]; then
    # Check if file has actual video content (duration > 0)
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$session_dir/tmp/after_replace.mp4" 2>/dev/null)
    if [ -n "$duration" ] && (( $(echo "$duration > 0" | bc -l) )); then
        has_after=true
    fi
fi

echo "Segments detected: before=$has_before, after=$has_after"

# Step 3: Concatenate segments based on what exists
mkdir -p "$session_dir/output"

if [ "$has_before" = true ] && [ "$has_after" = true ]; then
    # All three segments exist
    echo "Concatenating all three segments..."
    echo "file '$session_dir/tmp/before_replace.mp4'" > "$session_dir/tmp/concat_list.txt"
    echo "file '$session_dir/tmp/edited_segment.mp4'" >> "$session_dir/tmp/concat_list.txt"
    echo "file '$session_dir/tmp/after_replace.mp4'" >> "$session_dir/tmp/concat_list.txt"
    
    ffmpeg -y -f concat -safe 0 -i "$session_dir/tmp/concat_list.txt" \
      -c copy \
      "$session_dir/output/final_output.mp4"

elif [ "$has_before" = true ]; then
    # Only before + edited segments
    echo "Concatenating before + edited segments..."
    echo "file '$session_dir/tmp/before_replace.mp4'" > "$session_dir/tmp/concat_list.txt"
    echo "file '$session_dir/tmp/edited_segment.mp4'" >> "$session_dir/tmp/concat_list.txt"
    
    ffmpeg -y -f concat -safe 0 -i "$session_dir/tmp/concat_list.txt" \
      -c copy \
      "$session_dir/output/final_output.mp4"

elif [ "$has_after" = true ]; then
    # Only edited + after segments
    echo "Concatenating edited + after segments..."
    echo "file '$session_dir/tmp/edited_segment.mp4'" > "$session_dir/tmp/concat_list.txt"
    echo "file '$session_dir/tmp/after_replace.mp4'" >> "$session_dir/tmp/concat_list.txt"
    
    ffmpeg -y -f concat -safe 0 -i "$session_dir/tmp/concat_list.txt" \
      -c copy \
      "$session_dir/output/final_output.mp4"

else
    # Only edited segment exists
    echo "Only edited segment exists, copying as final output..."
    cp "$session_dir/tmp/edited_segment.mp4" "$session_dir/output/final_output.mp4"
fi

if [ -f "$session_dir/output/final_output.mp4" ]; then
    echo "✓ Final output created: $session_dir/output/final_output.mp4"
    
    # Update metadata.json with completion status
    if [ -f "$session_dir/metadata.json" ]; then
        jq '.status = "completed"' "$session_dir/metadata.json" > "$session_dir/metadata.json.tmp"
        mv "$session_dir/metadata.json.tmp" "$session_dir/metadata.json"
        echo "✓ Updated metadata.json"
    fi
else
    echo "✗ Error: Failed to create final output"
    exit 1
fi
