#!/bin/bash

# Dependency validation
command -v curl >/dev/null 2>&1 || { echo "Error: curl not found. Please install curl."; exit 1; }
command -v base64 >/dev/null 2>&1 || { echo "Error: base64 not found. Please install base64."; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not found. Please install jq."; exit 1; }

# Robust shell flags
set -euo pipefail

source .env

# Parse command-line arguments
session_dir=""
while getopts "t:n:d:" opt; do
    case $opt in
        t)
            text=$OPTARG;;
        n)
            number=$OPTARG;;
        d)
            session_dir=$OPTARG;;
        \?)
            echo "Usage: $0 -d <session_dir> -t <prompt text> -n <number of frames>"
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

# Validate session directory is provided
if [ -z "$session_dir" ]; then
    echo "Error: Session directory (-d) is required"
    echo "Usage: $0 -d <session_dir> -t <prompt text> -n <number of frames>"
    exit 1
fi

# Set up directories
OUT_DIR="$session_dir/output/frames"
mkdir -p "$OUT_DIR"

if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then
  B64FLAGS="--input"
else
  B64FLAGS="-w0"
fi

if [ -z "$text" ]; then
    text="Please add a subtitle saying, no subtitle specified. Don't change anything else"
fi

enhanced_text="$text

IMPORTANT INSTRUCTIONS FOR CONSISTENCY:
- Place the subtitle at EXACTLY the same position on every frame (bottom center, 10% from bottom)
- Use EXACTLY the same font size (approximately 5% of image height)
- Use EXACTLY the same font color (white with a black outline)
- Do NOT modify or alter the background image in any way except for adding the subtitle
- Maintain pixel-perfect consistency across ALL frames
"


generate_payload() {
    local img_id="$1"
    IMG_PATH="$session_dir/tmp/frames/frame_$img_id.png"
    IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)
    
    # Pass base64 image via stdin to avoid ARG_MAX overflow
    # printf pipes the base64 string into jq, which reads it via 'input'
    printf '%s' "$IMG_BASE64" | jq -R -n \
        --arg text "$enhanced_text" \
        '{
            contents: [{
                parts: [
                    {
                        inline_data: {
                            mime_type: "image/png",
                            data: input
                        }
                    },
                    { text: $text }
                ]
            }],
            generationConfig: {
                responseModalities: ["TEXT", "IMAGE"],
                imageConfig: { aspectRatio: "16:9" }
            }
        }'
}

update_img() {
    local img_id=$1
    local max_retries=1
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        # Perform API call with correct model endpoint
        response=$(generate_payload $img_id | curl -s -w "\n%{http_code}" -X POST \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
            -H "x-goog-api-key: $GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d @-)
        
        # Parse HTTP code and body
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" = "200" ]; then
            # Check if response contains image data
            # Note: Gemini API returns inlineData (camelCase), not inline_data
            image_data=$(echo "$body" | jq -r '.candidates[0].content.parts[].inlineData.data // empty' | head -n 1)
            
            if [ -n "$image_data" ]; then
                # Detect image format from base64 prefix
                # JPEG starts with /9j/ (FF D8 FF in hex)
                # PNG starts with iVBORw (89 50 4E 47 in hex)
                if [[ "$image_data" == /9j/* ]]; then
                    ext="jpg"
                else
                    ext="png"
                fi

                # Decode and save image with correct extension
                echo "$image_data" | base64 --decode > "$OUT_DIR/frame_$img_id.$ext"

                # Validate file is non-empty
                if [ -s "$OUT_DIR/frame_$img_id.$ext" ]; then
                    success=true
                    echo "✓ Frame $img_id completed ($ext)"
                else
                    echo "⚠ Frame $img_id: Decoded image is empty, retrying..."
                    rm -f "$OUT_DIR/frame_$img_id.$ext"
                    retry_count=$((retry_count + 1))
                    sleep 2
                fi
            else
                # No image data - check if API refused the request
                error_text=$(echo "$body" | jq -r '.candidates[0].content.parts[].text // empty' | head -n 1)
                [ -z "$error_text" ] && error_text="Unknown error"
                echo "⚠ Frame $img_id: No image data in response - $error_text"
                
                # Log full response for debugging
                if [ $retry_count -eq 0 ]; then
                    echo "$body" | jq '.' >> "$session_dir/tmp/api_errors.log" 2>&1 || echo "$body" >> "$session_dir/tmp/api_errors.log"
                fi
                
                retry_count=$((retry_count + 1))
                sleep 2
            fi
        
        elif [ "$http_code" = "429" ]; then
            # Rate limited — use extended backoff
            echo "⚠ Frame $img_id: Rate limited (429), waiting 15s..."
            retry_count=$((retry_count + 1))
            sleep 15
        
        else
            # Generic error with exponential backoff
            echo "✗ Frame $img_id: HTTP $http_code, retrying..."
            retry_count=$((retry_count + 1))
            sleep $((retry_count * 2))
        fi
    done
    
    # Final failure handling
    if [ "$success" = false ]; then
        echo "✗ Frame $img_id: FAILED after $max_retries retries"
        echo "$img_id" >> "$session_dir/tmp/failed_frames.txt"
        return 1
    fi
}

# Maximum parallel jobs to prevent API rate limiting and system overload
# Reduced to 3 to minimize 429 errors from Gemini API
MAX_JOBS=3

for i in $(seq -f "%05g" 1 "$number"); do
    # Wait if we've reached the max parallel job limit
    while [ $(jobs -r | wc -l) -ge "$MAX_JOBS" ]; do
        sleep 0.3
    done
    
    update_img "$i" &
done
wait

# Update metadata.json with prompt and status
if [ -f "$session_dir/metadata.json" ]; then
    # Read failed frames if any
    failed_frames="[]"
    if [ -f "$session_dir/tmp/failed_frames.txt" ]; then
        failed_frames=$(jq -R -s -c 'split("\n") | map(select(length > 0))' < "$session_dir/tmp/failed_frames.txt")
    fi
    
    jq --arg prompt "$text" \
       --argjson failed "$failed_frames" \
       '.prompt = $prompt | .status = "frames_generated" | .failed_frames = $failed' \
       "$session_dir/metadata.json" > "$session_dir/metadata.json.tmp"
    mv "$session_dir/metadata.json.tmp" "$session_dir/metadata.json"
    
    echo "✓ Updated metadata.json"
fi
