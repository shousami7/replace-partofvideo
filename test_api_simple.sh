#!/bin/bash

# Test script to diagnose API issues - shows just the content parts
source .env

# Test with first frame
IMG_PATH="runs/20251211_184920/tmp/frames/frame_00001.png"

if [ ! -f "$IMG_PATH" ]; then
    echo "Error: Frame not found at $IMG_PATH"
    exit 1
fi

echo "Testing API with frame: $IMG_PATH"
echo "================================"

# Detect base64 flags
if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then
  B64FLAGS="--input"
else
  B64FLAGS="-w0"
fi

IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)

PROMPT="delete caption"

# Create payload
payload=$(printf '%s' "$IMG_BASE64" | jq -R -n \
    --arg text "$PROMPT" \
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
            imageConfig: { aspectRatio: "16:9" }
        }
    }')

# Make API call
echo "Making API call..."
response=$(echo "$payload" | curl -s -w "\n%{http_code}" -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d @-)

# Parse response
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status Code: $http_code"
echo ""

# Show candidate parts structure
echo "Candidate parts structure:"
echo "$body" | jq '.candidates[0].content.parts' 2>&1

echo ""
echo "Checking for inline_data:"
echo "$body" | jq '.candidates[0].content.parts[] | select(.inline_data)' 2>&1

echo ""
echo "First 200 chars of first part:"
echo "$body" | jq -r '.candidates[0].content.parts[0] | tostring' 2>&1 | head -c 200
echo ""
