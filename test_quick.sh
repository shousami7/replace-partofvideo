#!/bin/bash

# Quick test - process just 2 frames to verify the fix works
source .env

SESSION_DIR="runs/20251211_184920"
PROMPT="delete caption"

echo "Testing with 2 frames..."
./parallel_gen.sh -d "$SESSION_DIR" -t "$PROMPT" -n 2

echo ""
echo "Results:"
ls -lh "$SESSION_DIR/output/frames/" | head -5

echo ""
echo "Checking if images are valid:"
for frame in "$SESSION_DIR/output/frames/frame_00001.png" "$SESSION_DIR/output/frames/frame_00002.png"; do
    if [ -f "$frame" ] && [ -s "$frame" ]; then
        size=$(wc -c < "$frame")
        echo "✓ $frame - $size bytes"
        file "$frame"
    else
        echo "✗ $frame - missing or empty"
    fi
done
