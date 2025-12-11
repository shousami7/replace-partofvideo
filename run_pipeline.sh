#!/bin/bash

# Dependency validation
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found. Please install jq."; exit 1; }

# Robust shell flags
set -euo pipefail

# Parse command-line arguments
input=""
start=""
end=""
fps="10"
prompt=""

while getopts "i:s:e:f:t:h" opt; do
    case $opt in
        i)
            input=$OPTARG;;
        s)
            start=$OPTARG;;
        e)
            end=$OPTARG;;
        f)
            fps=$OPTARG;;
        t)
            prompt=$OPTARG;;
        h)
            echo "Usage: $0 -i <input video> -s <start time> -e <end time> [-f <fps>] [-t <prompt>]"
            echo ""
            echo "Options:"
            echo "  -i  Input video file (required)"
            echo "  -s  Start time in seconds (required)"
            echo "  -e  End time in seconds (required)"
            echo "  -f  Frames per second (default: 10)"
            echo "  -t  AI prompt for frame editing (optional)"
            echo "  -h  Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 -i video.mp4 -s 5 -e 10 -f 10 -t 'Add subtitle saying Hello World'"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$input" ] || [ -z "$start" ] || [ -z "$end" ]; then
    echo "Error: Missing required parameters"
    echo "Use -h for help"
    exit 1
fi

# Validate input file exists
if [ ! -f "$input" ]; then
    echo "Error: Input file not found: $input"
    exit 1
fi

echo "========================================="
echo "Video Processing Pipeline"
echo "========================================="
echo "Input: $input"
echo "Time range: ${start}s - ${end}s"
echo "FPS: $fps"
if [ -n "$prompt" ]; then
    echo "Prompt: $prompt"
fi
echo "========================================="
echo ""

# Step 1: Separate video and extract frames
echo "Step 1/3: Extracting frames..."
session_output=$(./separate.sh -i "$input" -s "$start" -e "$end" -f "$fps" 2>&1)
echo "$session_output"

# Extract session directory from output
session_dir=$(echo "$session_output" | grep "Session directory:" | cut -d' ' -f3)

if [ -z "$session_dir" ]; then
    echo "Error: Failed to extract session directory"
    exit 1
fi

echo ""
echo "Session: $session_dir"
echo ""

# Step 2: Generate AI-edited frames (if prompt provided)
if [ -n "$prompt" ]; then
    # Count frames
    frame_count=$(find "$session_dir/tmp/frames" -name "frame_*.png" | wc -l | tr -d ' ')
    
    echo "Step 2/3: Generating AI-edited frames ($frame_count frames)..."
    ./parallel_gen.sh -d "$session_dir" -t "$prompt" -n "$frame_count"
    echo ""
else
    echo "Step 2/3: Skipping AI generation (no prompt provided)"
    echo "Copying original frames to output..."
    cp "$session_dir/tmp/frames"/*.png "$session_dir/output/frames/"
    echo ""
fi

# Step 3: Concatenate final video
echo "Step 3/3: Creating final video..."
./concatenate.sh -d "$session_dir"
echo ""

echo "========================================="
echo "✅ Pipeline Complete!"
echo "========================================="
echo "Session: $session_dir"
echo "Output: $session_dir/output/final_output.mp4"
echo "Metadata: $session_dir/metadata.json"
echo "========================================="
echo ""
echo "View metadata:"
echo "  cat $session_dir/metadata.json | jq ."
echo ""
echo "Play output:"
echo "  open $session_dir/output/final_output.mp4"
