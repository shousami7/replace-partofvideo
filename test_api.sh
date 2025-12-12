#!/bin/bash

# Test script to diagnose API issues
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
echo "Base64 encoded (first 100 chars): ${IMG_BASE64:0:100}..."
echo ""

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

echo "Payload structure (first 500 chars):"
echo "$payload" | jq '.' | head -20
echo ""

# Make API call
echo "Making API call..."
response=$(echo "$payload" | curl -s -w "\n%{http_code}" -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d @-)

# Parse response
http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status Code: $http_code"
echo ""
echo "Response Body:"
echo "$body" | jq '.' 2>&1 || echo "$body"
echo ""

# Try to extract image
if [ "$http_code" = "200" ]; then
    echo "Attempting to extract image data..."
    image_data=$(echo "$body" | jq -r '.candidates[0].content.parts[].inline_data.data // empty' 2>&1)
    
    if [ -n "$image_data" ]; then
        echo "✓ Image data found (length: ${#image_data})"
        echo "$image_data" | base64 --decode > /tmp/test_output.png
        echo "✓ Saved to /tmp/test_output.png"
        ls -lh /tmp/test_output.png
    else
        echo "✗ No image data found in response"
        echo "Response structure:"
        echo "$body" | jq 'keys' 2>&1
    fi
else
    echo "✗ API request failed with status $http_code"
fi
