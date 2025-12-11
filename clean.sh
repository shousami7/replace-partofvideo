#!/bin/bash

command -v rm >/dev/null 2>&1 || { echo "Error: rm not found."; exit 1; }

# Robust shell flags
set -euo pipefail

# Parse command-line arguments
clean_all=false
session_dir=""
keep_latest=0
skip_confirm=false

while getopts "ad:k:yh" opt; do
    case $opt in
        a)
            clean_all=true;;
        d)
            session_dir=$OPTARG;;
        k)
            keep_latest=$OPTARG
            if ! [[ "$keep_latest" =~ ^[0-9]+$ ]]; then
                echo "Error: -k requires a positive integer"
                exit 1
            fi
            ;;
        y)
            skip_confirm=true;;
        h)
            echo "Usage: $0 [-a] [-d <session_dir>] [-k <N>] [-y]"
            echo ""
            echo "Options:"
            echo "  -a      Clean all sessions in runs/ directory"
            echo "  -d DIR  Clean specific session directory"
            echo "  -k N    Keep N latest sessions, delete older ones"
            echo "  -y      Skip confirmation prompt (auto-yes)"
            echo "  -h      Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -a                           # Clean all sessions (with confirmation)"
            echo "  $0 -a -y                        # Clean all sessions (no confirmation)"
            echo "  $0 -k 3                         # Keep 3 latest sessions, delete rest"
            echo "  $0 -k 5 -y                      # Keep 5 latest, auto-confirm deletion"
            echo "  $0 -d runs/20251211_163422      # Clean specific session"
            echo "  $0                              # Clean legacy tmp/ and output/ directories"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Safety check: Ensure we're in a project directory
if [ -z "${PWD}" ] || [ "${PWD}" = "/" ] || [ "${PWD}" = "${HOME}" ]; then
    echo "Error: Refusing to run in root or home directory for safety."
    exit 1
fi

echo "🧹 Cleaning workspace..."
echo "Working directory: ${PWD}"
echo

# Track what was cleaned
cleaned_items=0

# Clean specific session
if [ -n "$session_dir" ]; then
    if [ ! -d "$session_dir" ]; then
        echo "Error: Session directory not found: $session_dir"
        exit 1
    fi
    
    echo "  Removing session: $session_dir"
    rm -rf "$session_dir"
    cleaned_items=$((cleaned_items + 1))

# Keep N latest sessions, delete older ones
elif [ "$keep_latest" -gt 0 ]; then
    if [ ! -d "runs" ] || [ -z "$(ls -A runs 2>/dev/null)" ]; then
        echo "  No sessions found in runs/"
    else
        # Get all session directories sorted by modification time (newest first)
        # Exclude 'latest' symlink
        all_sessions=()
        while IFS= read -r session; do
            all_sessions+=("$session")
        done < <(find runs -mindepth 1 -maxdepth 1 -type d ! -name "latest" -exec stat -f "%m %N" {} \; | sort -rn | cut -d' ' -f2-)
        
        total_sessions=${#all_sessions[@]}
        
        if [ "$total_sessions" -le "$keep_latest" ]; then
            echo "  Found $total_sessions session(s), keeping all (requested to keep $keep_latest)"
        else
            sessions_to_delete=$((total_sessions - keep_latest))
            echo "  Found $total_sessions session(s)"
            echo "  Keeping $keep_latest latest session(s)"
            echo "  Will delete $sessions_to_delete older session(s):"
            echo ""
            
            # Show sessions that will be deleted
            for ((i=keep_latest; i<total_sessions; i++)); do
                session_name=$(basename "${all_sessions[$i]}")
                echo "    - $session_name"
            done
            echo ""
            
            # Confirmation prompt
            if [ "$skip_confirm" = false ]; then
                read -p "  Proceed with deletion? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "  Cancelled."
                    exit 0
                fi
            fi
            
            # Delete old sessions
            for ((i=keep_latest; i<total_sessions; i++)); do
                session_path="${all_sessions[$i]}"
                session_name=$(basename "$session_path")
                echo "  Removing: $session_name"
                rm -rf "$session_path"
                cleaned_items=$((cleaned_items + 1))
            done
        fi
    fi
    
# Clean all sessions
elif [ "$clean_all" = true ]; then
    if [ -d "runs" ] && [ "$(ls -A runs 2>/dev/null)" ]; then
        # Count sessions (exclude 'latest' symlink)
        session_count=$(find runs -mindepth 1 -maxdepth 1 -type d ! -name "latest" | wc -l | tr -d ' ')
        
        if [ "$session_count" -eq 0 ]; then
            echo "  No sessions found in runs/"
        else
            echo "  Found $session_count session(s) in runs/"
            echo ""
            
            # Show all sessions
            echo "  Sessions to be deleted:"
            find runs -mindepth 1 -maxdepth 1 -type d ! -name "latest" -exec basename {} \; | sort | sed 's/^/    - /'
            echo ""
            
            # Confirmation prompt
            if [ "$skip_confirm" = false ]; then
                read -p "  Delete all $session_count session(s)? [y/N] " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "  Cancelled."
                    exit 0
                fi
            fi
            
            echo "  Removing all sessions in runs/ ($session_count sessions)"
            find runs -mindepth 1 -maxdepth 1 -type d ! -name "latest" -exec rm -rf {} +
            # Also remove the 'latest' symlink if it exists
            [ -L "runs/latest" ] && rm -f "runs/latest"
            cleaned_items=$session_count
        fi
    else
        echo "  No sessions found in runs/"
    fi

# Clean legacy tmp/ and output/ directories
else
    # Clean tmp/frames/*
    if [ -d "tmp/frames" ] && [ "$(ls -A tmp/frames 2>/dev/null)" ]; then
        echo "  Removing tmp/frames/*"
        rm -f tmp/frames/*
        cleaned_items=$((cleaned_items + 1))
    fi

    # Clean output/frames/*
    if [ -d "output/frames" ] && [ "$(ls -A output/frames 2>/dev/null)" ]; then
        echo "  Removing output/frames/*"
        rm -f output/frames/*
        cleaned_items=$((cleaned_items + 1))
    fi

    # Clean tmp/*.mp4
    if ls tmp/*.mp4 1>/dev/null 2>&1; then
        echo "  Removing tmp/*.mp4"
        rm -f tmp/*.mp4
        cleaned_items=$((cleaned_items + 1))
    fi

    # Clean tmp/fps.txt
    if [ -f "tmp/fps.txt" ]; then
        echo "  Removing tmp/fps.txt"
        rm -f tmp/fps.txt
        cleaned_items=$((cleaned_items + 1))
    fi

    # Clean tmp/failed_frames.txt
    if [ -f "tmp/failed_frames.txt" ]; then
        echo "  Removing tmp/failed_frames.txt"
        rm -f tmp/failed_frames.txt
        cleaned_items=$((cleaned_items + 1))
    fi

    # Clean tmp/concat_list.txt
    if [ -f "tmp/concat_list.txt" ]; then
        echo "  Removing tmp/concat_list.txt"
        rm -f tmp/concat_list.txt
        cleaned_items=$((cleaned_items + 1))
    fi

    # Recreate directories
    echo
    echo "📁 Recreating legacy directories..."
    mkdir -p tmp/frames
    mkdir -p output/frames
fi

echo
if [ $cleaned_items -eq 0 ]; then
    echo "✨ Workspace was already clean (no files to remove)"
else
    echo "✅ Cleanup complete! Removed $cleaned_items item(s)"
fi
