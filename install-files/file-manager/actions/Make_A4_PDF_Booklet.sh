#!/bin/bash
while (( $# )); do
    OUT="${1%.*}_bklt.pdf"
    bookletimposer --no-gui --booklet --pages-per-sheet=2x1 --format=A4 --output="$OUT" "$1"
  shift
done
