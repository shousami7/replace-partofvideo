#!/bin/bash

# Load fps from saved file
if [ -f "$PWD/tmp/fps.txt" ]; then
    fps=$(cat $PWD/tmp/fps.txt)
else
    fps=10
fi

# Validate fps (must be numeric)
if ! [[ "$fps" =~ ^[0-9]+$ ]]; then
    fps=10
fi

echo "Using fps: $fps"

# Concatenate frames back into video using the same fps
ffmpeg \
  -framerate $fps \
  -i $PWD/tmp/frames/frame_%05d.png \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -r $fps \
  $PWD/output/video1.mp4
