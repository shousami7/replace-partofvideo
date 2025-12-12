---
description: Run a 2‑3 second sky‑view cut and generate subtitles
---

## Overview
This workflow shows how to use the existing scripts in the **replace‑partofvideo** project to:
1. Initialise a session directory.
2. Extract a short video segment (2 s → 3 s).
3. Generate frames, run the Gemini image‑to‑text model, and re‑assemble the final video.

All commands assume you are in the project root (`/Users/shousami/replace-partofvideo`).

## Steps
1. **Create a session directory** (optional – the scripts will create one automatically if omitted):
   ```bash
   SESSION_DIR=$(pwd)/runs/$(date +%Y%m%d_%H%M%S)
   mkdir -p "$SESSION_DIR"
   ```

2. **Run `separate.sh` to cut the 2‑3 second segment**
   ```bash
   ./separate.sh \
       -i path/to/your/input.mp4 \
       -s 2 \
       -e 3 \
       -f 10 \
       -d "$SESSION_DIR"
   ```
   - `-s 2`  → start at 2 seconds
   - `-e 3`  → end at 3 seconds (duration = 1 second)
   - `-f 10` → extract frames at 10 fps (adjust as needed)
   - `-d`   → tells the script where to store the session files.

3. **Generate edited frames**
   ```bash
   ./parallel_gen.sh -d "$SESSION_DIR" -t "Your subtitle text here" -n $(cat "$SESSION_DIR/tmp/frames/"* | wc -l)
   ```
   - `-t` is the subtitle prompt.
   - `-n` is the number of frames (you can use `$(ls "$SESSION_DIR/tmp/frames" | wc -l)` to count them automatically).

4. **Concatenate the final video** (the script `concatenate.sh` is already set up to read the session directory):
   ```bash
   ./concatenate.sh -d "$SESSION_DIR"
   ```
   The final video will be written to `$SESSION_DIR/output/final.mp4`.

5. **Verify the result**
   ```bash
   open "$SESSION_DIR/output/final.mp4"
   ```
   (or use your preferred video player).

## Tips
- All scripts will abort with a clear error message if a required dependency (ffmpeg, jq, curl, etc.) is missing.
- You can change the `fps` value in step 2 to control how many frames are generated; a higher FPS yields smoother subtitles but more API calls.
- If you want to reuse the same session directory for multiple runs, simply delete the `tmp/` and `output/` sub‑folders before re‑executing the steps.

---
*This workflow is stored at `.agent/workflows/run_cut.md` for easy reference.*
