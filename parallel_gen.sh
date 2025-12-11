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


generate_payload() {
    IMG_PATH="$PWD/tmp/frames/frame_$1.png"
    IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)
  cat <<EOF
{
    "contents": [{
        "parts":[
            {"text":"$text"},
            {
                "inline_data":{
                    "mime_type":"image/jpeg",
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
    img_id=$1
    generate_payload $img_id | curl -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
    -H "x-goog-api-key: $GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d @- | grep -o '"data": "[^"]*"' | cut -d'"' -f4 | base64 --decode > $OUT_DIR/frame_$img_id.png
}

for i in $(seq -f "%05g" 10 $number); do
    update_img $i &
done
wait
