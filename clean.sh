#!/bin/bash

command -v rm >/dev/null 2>&1 || { echo "Error: rm not found."; exit 1; }

# Robust shell flags
set -euo pipefail

# Parse command-line arguments
clean_all=false
session_dir=""

while getopts "ad:h" opt; do
    case $opt in
        a)
            clean_all=true;;
        d)
            session_dir=$OPTARG;;
        h)
            echo "Usage: $0 [-a] [-d <session_dir>]"
            echo ""
            echo "Options:"
            echo "  -a  Clean all sessions in runs/ directory"
            echo "  -d  Clean specific session directory"
            echo "  -h  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 -a                           # Clean all sessions"
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
    
# Clean all sessions
elif [ "$clean_all" = true ]; then
    if [ -d "runs" ] && [ "$(ls -A runs 2>/dev/null)" ]; then
        session_count=$(find runs -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
        echo "  Removing all sessions in runs/ ($session_count sessions)"
        rm -rf runs/*
        cleaned_items=$((cleaned_items + session_count))
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
