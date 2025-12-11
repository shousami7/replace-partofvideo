#!/bin/bash

while getopts "i:s:e:f:" opt; do
    case $opt in
        i)
            input=$OPTARG;;
        s)
            start=$OPTARG;;
        e)
            end=$OPTARG;;
        f)
            fps=$OPTARG;;
        \?)
            echo "Usage: $0 -i <input mp4 file> -s <start time> -e <end time>"
            echo "Invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done

if [ -z "$input" ] || [ -z "$start" ] || [ -z "$end" ]; then
    echo "Usage: $0 -i <input mp4 file> -s <start time> -e <end time> (optional) -f <fps>"
    exit 1
fi

# Default fps to 10 if not provided
if [ -z "$fps" ]; then
    fps=10
fi

mkdir -p $PWD/tmp
mkdir -p $PWD/tmp/frames
echo "fps: $fps"

ffmpeg -i $input -t $start -c copy $PWD/tmp/before_replace.mp4
ffmpeg -i $input -ss $start -t $end -c copy $PWD/tmp/for_replace.mp4
ffmpeg -i $input -ss $end -c copy $PWD/tmp/after_replace.mp4

# Extract frames at specified fps and save fps value for concatenation
ffmpeg -i $PWD/tmp/for_replace.mp4 -vf "fps=$fps" $PWD/tmp/frames/frame_%05d.png

# Save fps to file for downstream scripts
echo "$fps" > $PWD/tmp/fps.txt
