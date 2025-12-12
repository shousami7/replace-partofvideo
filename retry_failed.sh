#!/bin/bash

source .env

OUT_DIR="$PWD/output/frames"
mkdir -p "$OUT_DIR"

# Parse command-line arguments
while getopts "t:" opt; do
    case $opt in
        t)
            text=$OPTARG;;
    esac
done

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
    IMG_PATH="$PWD/tmp/frames/frame_$img_id.png"
    IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)
    
    # Use jq to safely construct JSON, properly escaping all special characters
    jq -n \
        --arg text "$enhanced_text" \
        --arg img "$IMG_BASE64" \
        '{
            contents: [{
                parts: [
                    { text: $text },
                    {
                        inline_data: {
                            mime_type: "image/png",
                            data: $img
                        }
                    }
                ]
            }],
            generationConfig: {
                imageConfig: { aspectRatio: "16:9" }
            }
        }'
}

update_img() {
    local img_id=$1
    local max_retries=3
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        # Perform API call
        response=$(generate_payload $img_id | curl -s -w "\n%{http_code}" -X POST \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
            -H "x-goog-api-key: $GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d @-)
        
        # Parse HTTP code and body
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" = "200" ]; then
            # Extract image data and save using jq for robust JSON parsing
            echo "$body" | jq -r '.candidates[0].content.parts[].inline_data.data // empty' | base64 --decode > "$OUT_DIR/frame_$img_id.png"
            
            # Validate file is non-empty
            if [ -s "$OUT_DIR/frame_$img_id.png" ]; then
                success=true
                echo "✓ Frame $img_id completed"
            else
                echo "⚠ Frame $img_id: Empty response, retrying..."
                retry_count=$((retry_count + 1))
                sleep 2
            fi
        
        elif [ "$http_code" = "429" ]; then
            # Rate limited — use extended backoff
            echo "⚠ Frame $img_id: Rate limited (429), waiting 10s..."
            retry_count=$((retry_count + 1))
            sleep 10
        
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
        return 1
    fi
}

# Check if failed_frames.txt exists
if [ ! -f "$PWD/tmp/failed_frames.txt" ]; then
    echo "No failed frames found. Nothing to retry."
    exit 0
fi

# Count failed frames
failed_count=$(wc -l < "$PWD/tmp/failed_frames.txt")
echo "Found $failed_count failed frame(s) to retry"

# Create backup of failed frames list
cp "$PWD/tmp/failed_frames.txt" "$PWD/tmp/failed_frames_backup.txt"

# Clear the failed frames file for this retry run
> "$PWD/tmp/failed_frames.txt"

# Maximum parallel jobs
MAX_JOBS=6

# Retry each failed frame
while IFS= read -r img_id; do
    # Skip empty lines
    [ -z "$img_id" ] && continue
    
    # Wait if we've reached the max parallel job limit
    while [ $(jobs -r | wc -l) -ge "$MAX_JOBS" ]; do
        sleep 0.3
    done
    
    echo "Retrying frame $img_id..."
    update_img "$img_id" &
done < "$PWD/tmp/failed_frames_backup.txt"

wait

# Report results
if [ -s "$PWD/tmp/failed_frames.txt" ]; then
    still_failed=$(wc -l < "$PWD/tmp/failed_frames.txt")
    echo ""
    echo "Retry complete. $still_failed frame(s) still failed."
    echo "Check tmp/failed_frames.txt for remaining failures."
else
    echo ""
    echo "✓ All frames successfully retried!"
    rm -f "$PWD/tmp/failed_frames.txt" "$PWD/tmp/failed_frames_backup.txt"
fi
