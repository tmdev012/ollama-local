#!/bin/bash
# rebuild-models.sh — inject latest CHANGELOG entry into both Modelfiles, rebuild both models
# Usage: bash ~/ollama-local/scripts/rebuild-models.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$SCRIPT_DIR/CHANGELOG.md"
RED='\033[0;31m'; GREEN='\033[0;32m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}Sashi Model Rebuild${NC}"
echo "==================="

# Extract latest changelog entry (first ## v block)
LATEST=$(awk '/^## v/{found++} found==1 && !/^## v[0-9]/{print} found==2{exit}' "$CHANGELOG" | grep "^-" | head -10)
VERSION=$(grep "^## v" "$CHANGELOG" | head -1 | awk '{print $2}')
echo "Injecting changelog: $VERSION"
echo "$LATEST" | sed 's/^/  /'
echo ""

# Update the ## Latest Changes block in both Modelfiles
for MF in "$SCRIPT_DIR/Modelfile.fast" "$SCRIPT_DIR/Modelfile.8b"; do
    MODEL_NAME=$(basename "$MF")
    echo -e "${BLUE}Updating $MODEL_NAME...${NC}"
    # Replace the Latest Changes section with fresh content
    python3 - "$MF" "$VERSION" << 'PYEOF'
import sys, re
fpath, version = sys.argv[1], sys.argv[2]
with open(fpath) as f:
    content = f.read()

import subprocess
# Get latest changelog entry
result = subprocess.run(
    ["awk", '/^## v/{found++} found==1 && !/^## v[0-9]/{print} found==2{exit}', fpath.replace("Modelfile.fast","CHANGELOG.md").replace("Modelfile.8b","CHANGELOG.md")],
    capture_output=True, text=True, cwd=fpath.rsplit("/",1)[0]
)
# Just use the raw changelog file
import pathlib
clog = pathlib.Path(fpath).parent / "CHANGELOG.md"
lines = clog.read_text().split("\n")
entry = []
in_block = False
for line in lines:
    if line.startswith("## v"):
        if in_block:
            break
        in_block = True
        entry.append(line)
    elif in_block:
        entry.append(line)

new_section = "\n## Latest Changes — " + "\n".join(entry[1:]).strip()
# Replace existing Latest Changes block
pattern = r'\n## Latest Changes.*?(?=\n""")'
content = re.sub(pattern, "\n" + new_section, content, flags=re.DOTALL)
with open(fpath, "w") as f:
    f.write(content)
print(f"  Updated {fpath.split('/')[-1]}")
PYEOF
done

echo ""
echo -e "${BLUE}Rebuilding fast-sashi (3B)...${NC}"
ollama create fast-sashi -f "$SCRIPT_DIR/Modelfile.fast" && \
    echo -e "${GREEN}  fast-sashi rebuilt${NC}" || echo -e "${RED}  fast-sashi FAILED${NC}"

echo ""
echo -e "${BLUE}Rebuilding sashi-llama-8b (8B)...${NC}"
ollama create sashi-llama-8b -f "$SCRIPT_DIR/Modelfile.8b" && \
    echo -e "${GREEN}  sashi-llama-8b rebuilt${NC}" || echo -e "${RED}  sashi-llama-8b FAILED${NC}"

echo ""
echo -e "${GREEN}Done. Both models updated to $VERSION${NC}"
echo "  fast-sashi     → Modelfile.fast"
echo "  sashi-llama-8b → Modelfile.8b"
echo "  Changelog      → ~/Desktop/SASHI-CHANGELOG.md (symlink)"
