#!/usr/bin/env bash
#
# Apply these dotfiles to a machine.
#
#   ./install.sh             install: repo -> machine
#   ./install.sh --dry-run   show what would change, touch nothing
#   ./install.sh --save      save: machine -> repo
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=0
SAVE=0
STAMP=$(date +%s)

for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY_RUN=1 ;;
    -s|--save) SAVE=1 ;;
    -h|--help)
      sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) printf 'install.sh: unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

GREEN=$'\033[32m'; YELLOW=$'\033[33m'; RED=$'\033[31m'; DIM=$'\033[2m'; OFF=$'\033[0m'
log()  { printf '%s==>%s %s\n' "$GREEN" "$OFF" "$*"; }
skip() { printf '%s   %s%s\n' "$DIM" "$*" "$OFF"; }
warn() { printf '%swarn:%s %s\n' "$YELLOW" "$OFF" "$*"; }
die()  { printf '%serr:%s %s\n' "$RED" "$OFF" "$*" >&2; exit 1; }

# run <command...> — echoes instead of executing under --dry-run
run() {
  if (( DRY_RUN )); then
    printf '%s   would run:%s %s\n' "$DIM" "$OFF" "$*"
  else
    "$@"
  fi
}

# copy_tree <src-root> <dest-root> — mirror files, backing up any that differ
copy_tree() {
  local src_root=$1 dest_root=$2 src rel dest
  local total=0 changed=0

  [[ -d $src_root ]] || { skip "no $src_root"; return 0; }

  while IFS= read -r -d '' src; do
    total=$(( total + 1 ))
    rel=${src#"$src_root"/}
    dest="$dest_root/$rel"

    if [[ -L $dest ]]; then
      # Copying through the link would clobber whatever it points at.
      warn "removing symlink $dest (would write through to its target)"
      run rm -f "$dest"
    elif [[ -f $dest ]] && cmp -s "$src" "$dest"; then
      continue
    elif [[ -e $dest ]]; then
      run cp -a "$dest" "$dest.bak.$STAMP"
      skip "backed up ${dest/#$HOME/~}"
    fi

    run mkdir -p "$(dirname "$dest")"
    run cp "$src" "$dest"
    log "installed ${dest/#$HOME/~}"
    changed=$(( changed + 1 ))
  done < <(find "$src_root" -type f -print0)

  if (( changed )); then
    skip "$changed of $total file(s) updated"
  else
    skip "all $total file(s) already in sync"
  fi
}

# omarchy stores theme.name as a slug but `theme set` takes the display name.
slug() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'; }

# save_tree <repo-root> <live-root> — copy tracked files back from the machine.
# Iterates the repo side so new files on disk are never pulled in uninvited.
save_tree() {
  local repo_root=$1 live_root=$2 repof live rel
  local total=0 changed=0

  [[ -d $repo_root ]] || { skip "no $repo_root"; return 0; }

  while IFS= read -r -d '' repof; do
    total=$(( total + 1 ))
    rel=${repof#"$repo_root"/}
    live="$live_root/$rel"

    if [[ ! -e $live ]]; then
      warn "not on machine: ${live/#$HOME/~}"
      continue
    fi
    if cmp -s "$repof" "$live"; then
      continue
    fi

    run cp "$live" "$repof"
    log "saved $rel"
    changed=$(( changed + 1 ))
  done < <(find "$repo_root" -type f -print0)

  if (( changed )); then
    skip "$changed of $total file(s) saved"
  else
    skip "all $total file(s) already match the repo"
  fi
}

# ------------------------------------------------------------------ save ----

if (( SAVE )); then
  log "Config files"
  save_tree "$REPO_DIR/config" "$HOME/.config"

  log "Executables"
  save_tree "$REPO_DIR/bin" "$HOME/.local/bin"

  log "Session state"
  save_tree "$REPO_DIR/state" "$HOME/.local/state"

  CURRENT=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)
  if [[ -n $CURRENT ]] && command -v omarchy >/dev/null; then
    # theme.name is a slug ("flexoki-light"); theme list has display names.
    DISPLAY_NAME=$(omarchy theme list 2>/dev/null | awk -v cur="$CURRENT" '
      { s = tolower($0); gsub(/ /, "-", s); if (s == cur) { print; exit } }')
    if [[ -n $DISPLAY_NAME ]]; then
      current_theme_txt=$(cat "$REPO_DIR/theme.txt" 2>/dev/null || true)
      if [[ $current_theme_txt == "$DISPLAY_NAME" ]]; then
        skip "theme.txt already $DISPLAY_NAME"
      elif (( DRY_RUN )); then
        skip "would set theme.txt -> $DISPLAY_NAME"
      else
        printf '%s\n' "$DISPLAY_NAME" > "$REPO_DIR/theme.txt"
        log "theme.txt -> $DISPLAY_NAME"
      fi
    fi
  fi

  if command -v omarchy >/dev/null; then
    manifest=$(omarchy plugin list --json 2>/dev/null |
      python3 "$REPO_DIR/scripts/save-plugins.py" || true)
    if [[ -z $manifest ]]; then
      warn "could not read plugin list; plugins.txt left unchanged"
    elif [[ $manifest == "$(cat "$REPO_DIR/plugins.txt" 2>/dev/null)" ]]; then
      skip "plugins.txt already up to date"
    elif (( DRY_RUN )); then
      skip "would refresh plugins.txt"
    else
      printf '%s' "$manifest" > "$REPO_DIR/plugins.txt"
      log "plugins.txt refreshed"
    fi
  fi

  (( DRY_RUN )) && log "Dry run complete — nothing was changed" || log "Done"
  exit 0
fi

# ---------------------------------------------------------------- files ----

log "Config files"
copy_tree "$REPO_DIR/config" "$HOME/.config"

log "Executables"
copy_tree "$REPO_DIR/bin" "$HOME/.local/bin"
while IFS= read -r -d '' f; do
  run chmod +x "$f"
done < <(find "$REPO_DIR/bin" -type f -print0 2>/dev/null)

log "Session state"
copy_tree "$REPO_DIR/state" "$HOME/.local/state"

# ---------------------------------------------------------------- theme ----

if [[ -f $REPO_DIR/theme.txt ]]; then
  THEME=$(<"$REPO_DIR/theme.txt")
  CURRENT=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || true)
  if [[ $(slug "$CURRENT") == $(slug "$THEME") ]]; then
    skip "theme already $THEME"
  elif ! command -v omarchy >/dev/null; then
    warn "omarchy not found; skipping theme ($THEME)"
  else
    log "Theme"
    run omarchy theme set "$THEME"
  fi
fi

# -------------------------------------------------------------- plugins ----
# Format: <plugin-id><TAB><git-url><TAB><enabled|disabled>
if [[ -f $REPO_DIR/plugins.txt ]]; then
  log "Plugins"
  while IFS=$'\t' read -r id url state; do
    [[ -z ${id:-} || $id == \#* ]] && continue
    dir="$HOME/.config/omarchy/plugins/$id"

    if [[ -d $dir ]]; then
      skip "already installed: $id"
    elif ! command -v omarchy >/dev/null; then
      warn "omarchy not found; skipping plugin $id"
      continue
    else
      run omarchy plugin add "$url" --yes
      log "installed plugin $id"
    fi

    if [[ $state == enabled ]]; then
      enabled=$(omarchy plugin list --json 2>/dev/null |
        python3 "$REPO_DIR/scripts/plugin-enabled.py" "$id" || true)
      if [[ $enabled == True ]]; then
        skip "already enabled: $id"
      else
        run omarchy plugin enable "$id"
        log "enabled plugin $id"
      fi
    fi
  done < "$REPO_DIR/plugins.txt"
fi

# ------------------------------------------------------------- validate ----

if command -v hyprctl >/dev/null && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
  log "Reloading Hyprland"
  run hyprctl reload >/dev/null
  if (( ! DRY_RUN )); then
    errors=$(hyprctl configerrors 2>/dev/null || true)
    if [[ -n $errors && $errors != *"no errors"* ]]; then
      printf '%s%s%s\n' "$RED" "$errors" "$OFF"
      die "Hyprland reported config errors"
    fi
    printf '%s   %sconfigerrors: clean%s\n' "$DIM" "$GREEN" "$OFF"
  fi
else
  skip "no running Hyprland session; reload later with: hyprctl reload"
fi

(( DRY_RUN )) && log "Dry run complete — nothing was changed" || log "Done"
