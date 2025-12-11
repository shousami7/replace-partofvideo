#!/bin/bash

# master.sh - Orchestrates the entire video processing workflow
# 
# Usage: ./master.sh -i <input_video> -s <start_time> -e <end_time> -t <prompt_text> [-f <fps>] [-r]
#
# Options:
#   -i  Input video file
#   -s  Start time (format: HH:MM:SS or seconds)
#   -e  End time (format: HH:MM:SS or seconds)
#   -t  Prompt text for AI generation
#   -f  Frames per second (default: 10)
#   -r  Run retry_failed.sh if there are failed frames (optional)

# Dependency validation
command -v ffmpeg >/dev/null 2>&1 || { echo "Error: ffmpeg not found. Please install ffmpeg."; exit 1; }
command -v bc >/dev/null 2>&1 || { echo "Error: bc not found. Please install bc."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found. Please install jq."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo "Error: curl not found. Please install curl."; exit 1; }

# Robust shell flags
set -euo pipefail

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_stage() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}STAGE: $1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Parse command-line arguments
input=""
start=""
end=""
prompt=""
fps=10
run_retry=false

while getopts "i:s:e:t:f:r" opt; do
    case $opt in
        i)
            input=$OPTARG;;
        s)
            start=$OPTARG;;
        e)
            end=$OPTARG;;
        t)
            prompt=$OPTARG;;
        f)
            fps=$OPTARG;;
        r)
            run_retry=true;;
        \?)
            echo "Usage: $0 -i <input_video> -s <start_time> -e <end_time> -t <prompt_text> [-f <fps>] [-r]"
            echo "Options:"
            echo "  -i  Input video file"
            echo "  -s  Start time (format: HH:MM:SS or seconds)"
            echo "  -e  End time (format: HH:MM:SS or seconds)"
            echo "  -t  Prompt text for AI generation"
            echo "  -f  Frames per second (default: 10)"
            echo "  -r  Run retry_failed.sh if there are failed frames (optional)"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$input" ] || [ -z "$start" ] || [ -z "$end" ] || [ -z "$prompt" ]; then
    log_error "Missing required arguments"
    echo "Usage: $0 -i <input_video> -s <start_time> -e <end_time> -t <prompt_text> [-f <fps>] [-r]"
    exit 1
fi

# Validate input file exists
if [ ! -f "$input" ]; then
    log_error "Input file not found: $input"
    exit 1
fi

# Generate session ID and directory
session_id=$(date +%Y%m%d_%H%M%S)
session_dir="$PWD/runs/$session_id"

log_info "Starting video processing workflow"
log_info "Session ID: $session_id"
log_info "Session directory: $session_dir"
log_info "Input video: $input"
log_info "Time range: $start to $end"
log_info "FPS: $fps"
log_info "Prompt: $prompt"
log_info "Retry failed frames: $run_retry"

# ========================================
# STAGE 1: Separate video segments and extract frames
# ========================================
log_stage "1/4 - Separating video and extracting frames"

if ! ./separate.sh -i "$input" -s "$start" -e "$end" -f "$fps" -d "$session_dir"; then
    log_error "Failed to separate video and extract frames"
    exit 1
fi

log_success "Video separation and frame extraction completed"

# Count extracted frames
total_frames=$(find "$session_dir/tmp/frames" -name "frame_*.png" | wc -l | tr -d ' ')
log_info "Extracted $total_frames frames"

# ========================================
# STAGE 2: Generate AI-edited frames in parallel
# ========================================
log_stage "2/4 - Generating AI-edited frames"

if ! ./parallel_gen.sh -d "$session_dir" -t "$prompt" -n "$total_frames"; then
    log_error "Failed to generate AI-edited frames"
    exit 1
fi

log_success "AI frame generation completed"

# Check for failed frames
if [ -f "$session_dir/tmp/failed_frames.txt" ] && [ -s "$session_dir/tmp/failed_frames.txt" ]; then
    failed_count=$(wc -l < "$session_dir/tmp/failed_frames.txt" | tr -d ' ')
    log_warning "Found $failed_count failed frame(s)"
    
    # ========================================
    # STAGE 3 (Optional): Retry failed frames
    # ========================================
    if [ "$run_retry" = true ]; then
        log_stage "3/4 - Retrying failed frames"
        
        # Update retry_failed.sh to use session directory (needs to be updated)
        # For now, we'll copy the failed frames list to the old location temporarily
        mkdir -p "$PWD/tmp"
        cp "$session_dir/tmp/failed_frames.txt" "$PWD/tmp/failed_frames.txt"
        
        if ! ./retry_failed.sh -t "$prompt"; then
            log_warning "Some frames still failed after retry"
        else
            log_success "All failed frames successfully retried"
        fi
        
        # Copy results back
        if [ -f "$PWD/tmp/failed_frames.txt" ]; then
            cp "$PWD/tmp/failed_frames.txt" "$session_dir/tmp/failed_frames.txt"
        fi
        
        # Copy retried frames to session output
        for frame in "$PWD/output/frames"/*.png; do
            if [ -f "$frame" ]; then
                cp "$frame" "$session_dir/output/frames/"
            fi
        done
    else
        log_info "Skipping retry stage (use -r flag to enable)"
    fi
else
    log_success "No failed frames detected"
fi

# ========================================
# STAGE 4: Concatenate final video
# ========================================
log_stage "4/4 - Concatenating final video"

if ! ./concatenate.sh -d "$session_dir"; then
    log_error "Failed to concatenate final video"
    exit 1
fi

log_success "Final video concatenation completed"

# ========================================
# WORKFLOW COMPLETE
# ========================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}WORKFLOW COMPLETED SUCCESSFULLY${NC}"
echo -e "${GREEN}========================================${NC}"
log_success "Final output: $session_dir/output/final_output.mp4"
log_info "Session directory: $session_dir"

# Display final statistics
if [ -f "$session_dir/metadata.json" ]; then
    log_info "Metadata:"
    jq '.' "$session_dir/metadata.json"
fi

# Create a symlink to the latest run
ln -sf "$session_dir" "$PWD/runs/latest"
log_info "Latest run symlink: $PWD/runs/latest"

echo ""
log_success "All done! 🎉"
