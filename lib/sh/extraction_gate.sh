#!/bin/bash
# High-speed deterministic extraction gate - v2 (Quiet)
awk '
/"(liquidity|odds|price)":/ {
    gsub(/[",:{}]/, "", $0)
    print "TARGET_FOUND: " $1 " VALUE: " $2
}
' "$1"
