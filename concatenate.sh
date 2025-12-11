#!/bin/bash

ffmpeg -framerate 5 -i $PWD/output/frames/frame_%05d.png -c:v libx264 -pix_fmt yuv420p $PWD/output/video1.mp4

