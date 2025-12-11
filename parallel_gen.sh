#!/bin/bash

source .env

OUT_DIR=$PWD/output/frames
mkdir -p $OUT_DIR

while getopts "t:n:" opt; do
    case $opt in
        t)
            text=$OPTARG;;
        n)
            number=$OPTARG;;
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
    IMG_PATH="$PWD/tmp/frames/frame_$1.png"
    IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)
  cat <<EOF
{
    "contents": [{
        "parts":[
            {"text":"$enhanced_text"},
            {
                "inline_data":{
                    "mime_type":"image/png",
                    "data":"$IMG_BASE64"
                }
            }
        ]
    }],
    "generationConfig": {
        "imageConfig": {"aspectRatio": "16:9"}
    }
}
EOF
}

update_img() {
    local img_id=$1
    local max_retries=3
    local retry_count=0
    local success=false
    
    while [ $retry_count -lt $max_retries ] && [ "$success" = false ]; do
        # Perform API call
        response=$(generate_payload $img_id | curl -s -w "\n%{http_code}" -X POST \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
            -H "x-goog-api-key: $GEMINI_API_KEY" \
            -H "Content-Type: application/json" \
            -d @-)
        
        # Parse HTTP code and body
        http_code=$(echo "$response" | tail -n1)
        body=$(echo "$response" | sed '$d')
        
        if [ "$http_code" = "200" ]; then
            # Extract image data and save
            echo "$body" | grep -o '"data": "[^"]*"' | cut -d'"' -f4 | base64 --decode > $OUT_DIR/frame_$img_id.png
            
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

# Maximum parallel jobs to prevent API rate limiting and system overload
MAX_JOBS=6

for i in $(seq -f "%05g" 1 $number); do
    # Wait if we've reached the max parallel job limit
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do
        sleep 0.3
    done
    
    update_img $i &
done
wait
