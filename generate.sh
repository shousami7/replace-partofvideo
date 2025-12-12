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
while getopts "t:d:" opt; do
    case $opt in
        t)
            text=$OPTARG;;
        d)
            session_dir=$OPTARG;;
        \?)
            echo "Usage: $0 -d <session_dir> -t <prompt text>"
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

# Validate session directory is provided
if [ -z "$session_dir" ]; then
    echo "Error: Session directory (-d) is required"
    echo "Usage: $0 -d <session_dir> -t <prompt text>"
    exit 1
fi

# Set up paths
IMG_PATH="$session_dir/tmp/frames/frame_00001.png"
OUT_DIR="$session_dir/output/frames"

mkdir -p "$OUT_DIR"

if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then
  B64FLAGS="--input"
else
  B64FLAGS="-w0"
fi

IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)

if [ -z "$text" ]; then
    text="Please add a subtitle saying, no subtitle specified"
fi

echo "$text"

generate_payload() {
  cat <<EOF
{
  "contents": [{
    "parts":[
      {"text":"$text"},
      {
        "inline_data":{
          "mime_type":"image/png",
          "data":"$IMG_BASE64"
        }
      }
    ]
  }],
  "generationConfig": {
    "responseModalities": ["TEXT", "IMAGE"],
    "imageConfig": {
      "aspectRatio": "16:9",
      "imageSize": "2K"
    }
  }
}
EOF
}

# Get the response and extract image data
image_data=$(generate_payload | curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @- \
| jq -r '.candidates[0].content.parts[].inlineData.data // empty' | head -n 1)

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
    echo "$image_data" | base64 --decode > "$OUT_DIR/frame_00001.$ext"
    echo "✓ Frame saved as frame_00001.$ext"
else
    echo "✗ No image data in response"
    exit 1
fi
