#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$REPO_DIR/superwhisper.env"

log() { printf '==> Superwhisper: %s\n' "$*"; }
die() { printf 'error: Superwhisper: %s\n' "$*" >&2; exit 1; }

if ! command -v superwhisper >/dev/null 2>&1; then
  log "not installed; skipping language and model setup"
  exit 0
fi

case "$SUPERWHISPER_PROCESSING_MODE" in
  offline_lite) required_models=(transcription vocabulary voice-detection) ;;
  offline) required_models=(cohere-transcription cleanup vocabulary voice-detection) ;;
  *) die "unsupported processing mode '$SUPERWHISPER_PROCESSING_MODE'; choose offline_lite or offline" ;;
esac

json_value() {
  local key=$1 json=$2
  python3 -c '
import json
import sys

value = json.load(sys.stdin)
for part in sys.argv[1].split("."):
    value = value.get(part) if isinstance(value, dict) else None
print(value if value is not None else "")
' "$key" <<<"$json"
}

missing_model_count() {
  local json=$1
  python3 -c '
import json
import sys

data = json.load(sys.stdin)
required = set(sys.argv[1:])
models = {model.get("id"): model for model in data.get("models", [])}
missing = [model_id for model_id in required
           if (models.get(model_id, {}).get("download") or {}).get("state") != "installed"]
print(len(missing))
' "${required_models[@]}" <<<"$json"
}

models_json=$(superwhisper models show)
current_mode=$(json_value processing "$models_json")
if [[ $current_mode != "$SUPERWHISPER_PROCESSING_MODE" ]]; then
  log "selecting $SUPERWHISPER_PROCESSING_MODE"
  superwhisper models select "$SUPERWHISPER_PROCESSING_MODE" >/dev/null
fi

general_json=$(superwhisper general show)
current_language=$(json_value config.language "$general_json")
if [[ $current_language != "$SUPERWHISPER_LANGUAGE" ]]; then
  log "setting language to $SUPERWHISPER_LANGUAGE"
  superwhisper general set language "\"$SUPERWHISPER_LANGUAGE\"" >/dev/null
fi

models_json=$(superwhisper models show)
missing=$(missing_model_count "$models_json")
if (( missing > 0 )); then
  if [[ $SUPERWHISPER_PROCESSING_MODE == offline_lite ]]; then
    size="about 823 MB"
  else
    size="about 2.3 GB"
  fi
  log "$SUPERWHISPER_PROCESSING_MODE needs local models ($size); starting the download"
  superwhisper models prepare
else
  log "$SUPERWHISPER_PROCESSING_MODE models are already downloaded"
fi
