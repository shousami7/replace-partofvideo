#!/bin/bash

source .env

IMG_PATH=$PWD/tmp/frames/frame_00001.png
OUT_DIR=$PWD/output/frames

mkdir -p $OUT_DIR

if [[ "$(base64 --version 2>&1)" = *"FreeBSD"* ]]; then
  B64FLAGS="--input"
else
  B64FLAGS="-w0"
fi

IMG_BASE64=$(base64 "$B64FLAGS" "$IMG_PATH" 2>&1)

while getopts "t:" opt; do
    case $opt in
        t)
            text=$OPTARG;;
    esac
done

if [ -z "$text" ]; then
    text="Please add a subtitle saying, no subtitle specified"
fi

echo $text

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
  }]
}
EOF
}

generate_payload | curl -X POST \
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-image:generateContent" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @- | grep -o '"data": "[^"]*"' | cut -d'"' -f4 | base64 --decode > $OUT_DIR/frame_00001.png
