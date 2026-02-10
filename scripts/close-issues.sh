#!/bin/bash
# Close all open issues in this repository
set -e
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)
if [ -z "$REPO" ]; then echo "Error: not in a GitHub repo"; exit 1; fi
echo "Closing all open issues in $REPO..."
ISSUES=$(gh issue list --repo "$REPO" --state open --json number,title --jq '.[] | "#\(.number) \(.title)"')
if [ -z "$ISSUES" ]; then echo "No open issues."; exit 0; fi
echo "$ISSUES" | while IFS= read -r line; do
  num=$(echo "$line" | grep -oP '(?<=#)\d+')
  gh issue close "$num" --repo "$REPO" --comment "Closed via scripts/close-issues.sh"
  echo "  Closed $line"
done
echo "Done."
