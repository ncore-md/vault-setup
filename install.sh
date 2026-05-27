#!/usr/bin/env bash
# install.sh — Vault Setup Wizard for Claude Code vault-rules system.
# Usage: ./install.sh [--vault-name NAME] [--dry-run]
# Installs hooks, skill, brief into ~/.claude/ and sets up a new vault.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUNDLE="$SCRIPT_DIR/bundle"
HOME_DIR="${HOME:-$(eval echo ~$USER)}"
CLAUDE="$HOME_DIR/.claude"

# Defaults
VAULT_NAME=""
DRY_RUN=false

# ── Argument parsing ───────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --vault-name) VAULT_NAME="$2"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers (must be before functions that call them) ───────────────
log()  { /bin/echo "[vault-setup] $*"; }
warn() { /bin/echo "[vault-setup] WARNING: $*" >&2; }

# ── Vault discovery & selection ────────────────────────────────────
_discover_vaults() {
  local vault_dir="$HOME_DIR/.vault"
  if [[ -d "$vault_dir" ]]; then
    find "$vault_dir" -mindepth 1 -maxdepth 1 -type d | sort
  fi
}

_prompt_vault_selection() {
  local existing
  existing="$(_discover_vaults)"

  if [[ -n "$existing" ]]; then
    echo ""
    log "Found existing vaults:"
    local i=1
    while IFS= read -r v; do
      echo "  $i) $(basename "$v") — $v"
      i=$((i + 1))
    done <<< "$existing"

    echo ""
    _prompt_msg="Which vault would you like to use? ($((i-1)) existing + create new) [default: $i = create new] "
    _prompt_msg="${_prompt_msg% ]}"
    echo -n "$_prompt_msg" >&2
    read -r choice
    choice="${choice:-$i}"

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 )) && (( choice < i )); then
      VAULT_ROOT="$(echo "$existing" | sed -n "${choice}p")"
    else
      # Create new vault — ask for name
      echo -n "Name for the new vault: " >&2
      read -r VAULT_NAME
      if [[ -z "$VAULT_NAME" ]]; then
        echo "[vault-setup] Vault name is required." >&2
        exit 1
      fi
      VAULT_ROOT="$HOME_DIR/.vault/$VAULT_NAME"

      if [[ -d "$VAULT_ROOT" ]]; then
        echo "[vault-setup] Vault already exists at $VAULT_ROOT." >&2
        exit 1
      fi
    fi
  else
    # No existing vaults — ask for name
    echo -n "Name for your new vault: " >&2
    read -r VAULT_NAME
    if [[ -z "$VAULT_NAME" ]]; then
      echo "[vault-setup] Vault name is required." >&2
      exit 1
    fi
    VAULT_ROOT="$HOME_DIR/.vault/$VAULT_NAME"

    if [[ -d "$VAULT_ROOT" ]]; then
      echo "[vault-setup] Vault already exists at $VAULT_ROOT." >&2
      exit 1
    fi
  fi

  log "Using vault: $VAULT_ROOT"
}

# ── Obsidian registration helpers ─────────────────────────────────
_OBSSI_CONFIG="$HOME_DIR/Library/Application Support/Obsidian/obsidian.json"

_register_obsidian_vault() {
  local vault_path="$1"
  if [[ ! -f "$_OBSSI_CONFIG" ]]; then
    warn "No obsidian.json found at $_OBSSI_CONFIG — skipping Obsidian registration."
    return 0
  fi

  # Generate a unique ID for this vault (sha256 of path, first 16 chars)
  local id
  id="$(echo "$vault_path" | shasum -a 256 | cut -d' ' -f1 | head -c 16)"

  # Check if already registered
  local existing_path
  existing_path="$(jq -r --arg id "$id" '.vaults[$id].path // ""' "$_OBSSI_CONFIG" 2>/dev/null)"
  if [[ -n "$existing_path" ]]; then
    log "Vault already registered in Obsidian (id=$id)"
    return 0
  fi

  # Register the vault in obsidian.json
  local tmp="${_OBSSI_CONFIG}.tmp"
  jq --arg id "$id" \
     --arg path "$vault_path" \
     '.vaults[$id] = {"path": $path}' \
     "$_OBSSI_CONFIG" > "$tmp" && mv "$tmp" "$_OBSSI_CONFIG"

  log "Registered vault in Obsidian (id=$id, path=$vault_path)"
}

_register_pi_vault() {
  local vault_path="$1"
  mkdir -p "$HOME_DIR/.pi"

  # Append to pi-vault-path (one per line)
  if [[ -f "$HOME_DIR/.pi/pi-vault-path" ]]; then
    grep -qxF "$vault_path" "$HOME_DIR/.pi/pi-vault-path" 2>/dev/null || echo "$vault_path" >> "$HOME_DIR/.pi/pi-vault-path"
  else
    echo "$vault_path" > "$HOME_DIR/.pi/pi-vault-path"
  fi

  log "Registered vault path in ~/.pi/pi-vault-path"
}

# ── Default vault name ─────────────────────────────────────────────
if [[ -z "$VAULT_NAME" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    VAULT_NAME="DemoVault"  # placeholder for dry-run preview
  else
    _prompt_vault_selection
  fi
fi

VAULT_ROOT="${VAULT_ROOT:-$HOME_DIR/.vault/$VAULT_NAME}"
HOOKS_DIR="$CLAUDE/hooks"
SKILLS_DIR="$CLAUDE/skills"

# ── Dynamic node path detection ────────────────────────────────────
_detect_node() {
  # Try: node --print-process-exec-path (Node ≥18) → nvm default → brew → PATH
  if node --print-process-exec-path &>/dev/null; then
    node --print-process-exec-path
  elif [[ -f "${HOME_DIR}/.nvm/versions/node/v22.22.2/bin/node" ]]; then
    echo "${HOME_DIR}/.nvm/versions/node/v22.22.2/bin/node"
  elif command -v node &>/dev/null; then
    # Resolve to absolute path (handles symlinks like /usr/local/bin/node → brew)
    local p; p="$(command -v node)" && readlink -f "$p" 2>/dev/null || which node
  else
    warn "Node not found — cannot register hooks in settings.json"
    return 1
  fi
}

NODE_PATH=""

jq_merge_settings() {
  # Merge hook entries into settings.json using jq (with python fallback).
  local vault_path="$1"
  local read_matcher="Read:${vault_path}"

  # Check if jq is available
  if command -v jq &>/dev/null; then
    _jq_merge_with_jq "$vault_path" "$read_matcher"
  elif command -v python3 &>/dev/null; then
    _jq_merge_with_python "$vault_path" "$read_matcher"
  else
    warn "Neither jq nor python3 found. Cannot update settings.json."
    warn "Add these entries manually to ~/.claude/settings.json under PreToolUse:"
    echo ""
    echo "  Bash:*obsidian*|wiki_tool → inject hook"
    echo "  Write|Edit                → validate hook"
    echo "  ${read_matcher}           → inject on Read"
    return 1
  fi
}

_jq_merge_with_jq() {
  local vault_path="$1" read_matcher="$2"
  local settings="$CLAUDE/settings.json"

  if [[ ! -f "$settings" ]]; then
    warn "No settings.json found at $settings. Skipping hook registration."
    return 1
  fi

  # Detect node once (cached)
  if [[ -z "$NODE_PATH" ]]; then
    NODE_PATH="$(_detect_node)" || return 1
  fi

  # Helper: check if a matcher already has the vault-rules hook
  _has_vault_hook() {
    local matcher="$1"
    jq -e ".hooks.PreToolUse[] | select(.matcher == \$m) | .hooks[] | select(.command // \"\" | contains(\"vault-rules-\"))" "$settings" --arg m "$matcher" &>/dev/null
  }

  # Helper: add a hook entry if not present (jq approach).
  # Uses --arg to pass command strings safely — avoids shell-quote injection into JSON.
  _add_hook() {
    local matcher="$1" inject_path="$2" validate_path="$3"

    if ! _has_vault_hook "$matcher"; then
      if [[ "$DRY_RUN" == true ]]; then
        log "[dry-run] Would add vault-rules hooks for matcher: $matcher"
      else
        if [[ "$matcher" == "Bash"* ]]; then
          jq --arg m    "$matcher" \
             --arg node  "$NODE_PATH" \
             --arg script "$inject_path" \
            '.hooks.PreToolUse += [{"matcher":$m,"type":"command","timeout":15}] |
             .hooks.PreToolUse = [.hooks.PreToolUse[] | if .matcher == $m then (. + {"command":($node + " " + $script)}) else . end]' \
            "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
          log "Added inject hook for matcher: $matcher"
        elif [[ -n "$validate_path" ]]; then
          jq --arg m     "$matcher" \
             --arg node  "$NODE_PATH" \
             --arg script "$validate_path" \
            '.hooks.PreToolUse += [{"matcher":$m,"type":"command","timeout":5}] |
             .hooks.PreToolUse = [.hooks.PreToolUse[] | if .matcher == $m then (. + {"command":($node + " " + $script)}) else . end]' \
            "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
          log "Added validate hook for matcher: $matcher"
        elif [[ -n "$inject_path" ]]; then
          jq --arg m     "$matcher" \
             --arg node  "$NODE_PATH" \
             --arg script "$inject_path" \
            '.hooks.PreToolUse += [{"matcher":$m,"type":"command","timeout":15}] |
             .hooks.PreToolUse = [.hooks.PreToolUse[] | if .matcher == $m then (. + {"command":($node + " " + $script)}) else . end]' \
            "$settings" > "${settings}.tmp" && mv "${settings}.tmp" "$settings"
          log "Added inject hook for matcher: $matcher"
        fi
      fi
    else
      log "Vault-rules hooks already registered for matcher: $matcher"
    fi
  }

  _add_hook "Bash:*obsidian*|wiki_tool" "$HOOKS_DIR/vault-rules-inject.js" ""
  _add_hook "Write|Edit" "" "$HOOKS_DIR/vault-rules-validate.js"
  _add_hook "$read_matcher" "$HOOKS_DIR/vault-rules-inject.js" ""

  return 0
}

_jq_merge_with_python() {
  local vault_path="$1" read_matcher="$2"
  local settings="$CLAUDE/settings.json"

  if [[ ! -f "$settings" ]]; then
    warn "No settings.json found at $settings. Skipping hook registration."
    return 1
  fi

  python3 - "$settings" "$vault_path" "$read_matcher" "$DRY_RUN" "$HOME_DIR" "$HOOKS_DIR" "$NODE_PATH" <<'PYTHON_SCRIPT'
import json, sys

settings_path = sys.argv[1]
vault_path    = sys.argv[2]
read_matcher  = sys.argv[3]
dry_run       = sys.argv[4] == "true"
home          = sys.argv[5]
hooks_dir     = sys.argv[6]
node_path     = sys.argv[7]

with open(settings_path) as f:
    data = json.load(f)

inject_cmd  = node_path + " " + hooks_dir + "/vault-rules-inject.js"
validate_cmd = node_path + " " + hooks_dir + "/vault-rules-validate.js"

def has_vault_hook(matcher):
    for entry in data.get("hooks", {}).get("PreToolUse", []):
        if entry.get("matcher") == matcher:
            for h in entry.get("hooks", []):
                if "vault-rules-" in (h.get("command") or ""):
                    return True
    return False

def add_hook(matcher, cmd, timeout=15):
    if has_vault_hook(matcher):
        print(f"[vault-setup] Vault-rules hooks already registered for matcher: {matcher}")
        return

    if dry_run:
        print(f"[vault-setup] [dry-run] Would add vault-rules hook for matcher: {matcher}")
        return

    # Find existing entry or create new one
    found = False
    for entry in data["hooks"]["PreToolUse"]:
        if entry.get("matcher") == matcher:
            hook = {"type": "command", "command": cmd, "timeout": timeout}
            if hook not in entry["hooks"]:
                entry["hooks"].append(hook)
            found = True
            break

    if not found:
        hook = {"type": "command", "command": cmd, "timeout": timeout}
        data["hooks"]["PreToolUse"].append({"matcher": matcher, "hooks": [hook]})

    print(f"[vault-setup] Added hook for matcher: {matcher}")

# Add hooks
add_hook("Bash:*obsidian*|wiki_tool", inject_cmd)
add_hook("Write|Edit", validate_cmd, timeout=5)
add_hook(read_matcher, inject_cmd)

with open(settings_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

PYTHON_SCRIPT

  if [[ $? -eq 0 ]]; then
    log "settings.json updated via python3"
  else
    warn "Python merge failed."
    return 1
  fi
}

# ── Pre-flight checks ──────────────────────────────────────────────
if [[ ! -d "$BUNDLE" ]]; then
  echo "ERROR: Bundle directory not found at $BUNDLE"
  exit 1
fi

if [[ ! -f "$CLAUDE/settings.json" ]]; then
  warn "No settings.json at $CLAUDE/settings.json. Hooks won't be registered."
  warn "Run this script after Claude Code is installed and configured."
fi

# ── Step 1: Install hooks into ~/.claude/hooks/ ───────────────────
log "Installing hooks to $HOOKS_DIR"

if [[ ! -d "$HOOKS_DIR" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would create $HOOKS_DIR"
  else
    mkdir -p "$HOOKS_DIR"
    log "Created $HOOKS_DIR"
  fi
fi

for hook in "$BUNDLE/hooks/"*.js; do
  [[ -f "$hook" ]] || continue
  local_name="$(basename "$hook")"
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would install bundle/hooks/$local_name → $HOOKS_DIR/"
  else
    cp "$hook" "$HOOKS_DIR/$local_name"
    log "Installed $local_name"
  fi
done

# ── Step 2: Install skill into ~/.claude/skills/ ───────────────────
log "Installing vault-rules skill to $SKILLS_DIR/vault-rules"

if [[ "$DRY_RUN" == true ]]; then
  log "[dry-run] Would install skill to $SKILLS_DIR/vault-rules/"
else
  mkdir -p "$SKILLS_DIR/vault-rules"
  cp "$BUNDLE/skills/vault-rules/SKILL.md" "$SKILLS_DIR/vault-rules/"
  log "Installed SKILL.md → vault-rules/"
fi

# ── Step 3: Install brief into ~/.claude/ ─────────────────────────
log "Installing vault-brief.md to $CLAUDE"

if [[ "$DRY_RUN" == true ]]; then
  log "[dry-run] Would install bundle/brief/vault-brief.md → $CLAUDE/"
else
  cp "$BUNDLE/brief/vault-brief.md" "$CLAUDE/"
  log "Installed vault-brief.md"
fi

# ── Step 4: Create or populate vault ───────────────────────────────
if [[ -d "$VAULT_ROOT" ]]; then
  log "Vault already exists at $VAULT_ROOT — populating missing files"

  # Ensure subdirectories exist
  mkdir -p "$VAULT_ROOT/Wiki/Topics" \
           "$VAULT_ROOT/Wiki/Concepts" \
           "$VAULT_ROOT/Wiki/Entities" \
           "$VAULT_ROOT/Wiki/Projects" \
           "$VAULT_ROOT/Wiki/Logs" \
           "$VAULT_ROOT/Raw/Sources" \
           "$VAULT_ROOT/Raw/Files" \
           "$VAULT_ROOT/Schema" \
           "$VAULT_ROOT/_templates/"

elif [[ "$DRY_RUN" != true ]]; then
  log "Creating new vault at $VAULT_ROOT"

  mkdir -p "$VAULT_ROOT/Wiki/Topics" \
           "$VAULT_ROOT/Wiki/Concepts" \
           "$VAULT_ROOT/Wiki/Entities" \
           "$VAULT_ROOT/Wiki/Projects" \
           "$VAULT_ROOT/Wiki/Logs" \
           "$VAULT_ROOT/Raw/Sources" \
           "$VAULT_ROOT/Raw/Files" \
           "$VAULT_ROOT/Schema" \
           "$VAULT_ROOT/_templates/"

  # Seed index.md at vault root (in Wiki/)
  cat > "$VAULT_ROOT/Wiki/index.md" <<'INDEX'
# Wiki Index

Related: [[AGENTS.md]], [[Schema/frontmatter-schema.md]]

## Topics

_No notes yet._

## Concepts

_No notes yet._

## Entities

_No notes yet._

## Projects

_No notes yet._
INDEX

else
  log "[dry-run] Would create vault at $VAULT_ROOT"
fi

# ── Step 4b: Copy AGENTS.md (always) ─────────────────────────────
if [[ ! -f "$VAULT_ROOT/AGENTS.md" ]]; then
  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would copy AGENTS.md → vault root"
  else
    cp "$BUNDLE/AGENTS.md" "$VAULT_ROOT/"
    log "Installed AGENTS.md → vault root"
  fi
fi

# ── Step 4c: Copy templates (always) ─────────────────────────────
for tpl in "$BUNDLE/templates/"*.md; do
  [[ -f "$tpl" ]] || continue
  local_name="$(basename "$tpl")"
  if [[ ! -f "$VAULT_ROOT/_templates/$local_name" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      log "[dry-run] Would copy template $local_name"
    else
      cp "$tpl" "$VAULT_ROOT/_templates/"
      log "Installed template: $local_name"
    fi
  else
    log "Template already exists: $local_name — skipping"
  fi
done

# ── Step 4d: Extract scripts (always) ────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  log "[dry-run] Would extract scripts.tar.gz → vault/scripts/"
else
  mkdir -p "$VAULT_ROOT/scripts"
  tar xzf "$BUNDLE/scripts.tar.gz" -C "$VAULT_ROOT/scripts/" 2>/dev/null || true
  chmod +x "$VAULT_ROOT/scripts"/*.py 2>/dev/null || true
  log "Extracted wiki_tool.py, audit_public.py → scripts/"
fi

# ── Step 5: Write hook state file ─────────────────────────────────
log "Writing hook state file for vault path resolution"

if [[ "$DRY_RUN" == true ]]; then
  log "[dry-run] Would write vault-rules-state.json with path: $VAULT_ROOT"
else
  mkdir -p "$HOOKS_DIR"

  # Merge new vault path into existing state (or create fresh)
  _state_file="$HOOKS_DIR/vault-rules-state.json"

  if [[ -f "$_state_file" ]]; then
    # Append VAULT_ROOT to vault_paths only if not already present
    _merged="$(jq --arg p "$VAULT_ROOT" \
      'if (.vault_paths | index($p)) then . else .vault_paths += [$p] end' \
      "$_state_file")"
    echo "$_merged" > "$_state_file"
  else
    cat > "$_state_file" <<EOF
{"vault_path":"$VAULT_ROOT","vault_paths":["$VAULT_ROOT"]}
EOF
  fi

  log "Wrote vault-rules-state.json → $HOOKS_DIR/"
fi

# ── Step 6: Register hooks in settings.json ───────────────────────
if [[ -f "$CLAUDE/settings.json" ]]; then
  log "Registering hooks in settings.json"

  if [[ "$DRY_RUN" == true ]]; then
    log "[dry-run] Would register vault-rules hooks in settings.json"
  else
    if command -v jq &>/dev/null; then
      _jq_merge_with_jq "$VAULT_ROOT" "Read:${VAULT_ROOT}" || warn "settings.json merge failed (jq)"
    elif command -v python3 &>/dev/null; then
      _jq_merge_with_python "$VAULT_ROOT" "Read:${VAULT_ROOT}" || warn "settings.json merge failed (python3)"
    else
      warn "Cannot update settings.json: no jq or python3 available."
    fi
  fi
else
  warn "settings.json not found — hooks will NOT fire automatically."
fi

# ── Step 7: Register vault with Obsidian & skill discovery ───────
if [[ "$DRY_RUN" != true ]]; then
  _register_obsidian_vault "$VAULT_ROOT" || warn "Obsidian registration skipped"
  _register_pi_vault "$VAULT_ROOT"
fi

# ── Step 8: Dependency checks ─────────────────────────────────────
log "Checking dependencies"

if command -v python3 &>/dev/null; then
  PYTHON_VER=$(python3 --version 2>&1)
  log "Python: $PYTHON_VER (OK)"
else
  warn "python3 not found. wiki_tool.py requires Python 3.8+."
fi

if command -v node &>/dev/null; then
  NODE_VER=$(node --version 2>&1)
  log "Node: $NODE_VER (OK)"
else
  warn "node not found. Hooks require Node.js."
fi

if command -v obsidian &>/dev/null; then
  log "Obsidian CLI: installed (OK)"
else
  warn "obsidian CLI not found at /usr/local/bin/obsidian. Some features will be unavailable."
fi

# ── Summary ────────────────────────────────────────────────────────
if [[ "$DRY_RUN" == true ]]; then
  echo ""
  log "Dry run complete. No changes were made."
else
  echo ""
  log "Vault setup complete!"
  log "  Vault root:        $VAULT_ROOT"
  log "  Hooks:        $HOOKS_DIR/vault-rules-{inject,validate}.js"
  log "  Skill:        $SKILLS_DIR/vault-rules/SKILL.md"
  log "  Brief:        $CLAUDE/vault-brief.md"
  echo ""
  log "Next steps:"
  log "  cd $VAULT_ROOT"
  log "  python3 scripts/wiki_tool.py doctor && build && lint"

  # Run a quick health check if all tools are available
  if command -v python3 &>/dev/null && [[ -f "$VAULT_ROOT/scripts/wiki_tool.py" ]]; then
    echo ""
    log "Running quick health check..."
    cd "$VAULT_ROOT" && python3 scripts/wiki_tool.py doctor 2>&1 || true
    cd "$VAULT_ROOT" && python3 scripts/wiki_tool.py build 2>&1 || true
    cd "$VAULT_ROOT" && python3 scripts/wiki_tool.py lint 2>&1 || true
    echo ""
    log "Health check complete."
  fi
fi
