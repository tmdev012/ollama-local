#!/bin/bash
# ALIAS LOADER - single source point for .bashrc/.zshrc
_ALIAS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
for _af in "$_ALIAS_DIR"/core.sh "$_ALIAS_DIR"/ollama.sh "$_ALIAS_DIR"/pipe.sh "$_ALIAS_DIR"/git.sh "$_ALIAS_DIR"/nav.sh; do
    [ -f "$_af" ] && source "$_af"
done
unset _af _ALIAS_DIR
