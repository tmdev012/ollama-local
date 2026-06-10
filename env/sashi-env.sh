export SASHI_ROOT="${SASHI_ROOT:-$HOME/sashi-ide}"
export SASHI_REGISTRY="$SASHI_ROOT/registry"
export SASHI_EVIDENCE="$SASHI_ROOT/evidence"
export SASHI_CACHE="$SASHI_ROOT/cache"
export SASHI_ARCHIVE="$SASHI_ROOT/archive"
export SASHI_VAULT="$HOME/.sashi-vault"

case ":$PATH:" in
  *":$SASHI_ROOT/bin:"*) ;;
  *) export PATH="$SASHI_ROOT/bin:$PATH" ;;
esac
