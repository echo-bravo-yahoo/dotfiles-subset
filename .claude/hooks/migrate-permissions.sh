#!/bin/bash
# migrate-permissions.sh — PreToolUse hook
#
# Migrates Bash/Read/Edit/Write/Glob/Grep/WebFetch entries from
# settings.local.json into cc-allow's .config/cc-allow.local.toml so
# cc-allow evaluates them. Runs BEFORE cc-allow in the hook chain.
#
# Glob and Grep entries route to [read.allow] (cc-allow's glob/grep
# inherit from read via respect_file_rules).
#
# Caveat: writes only to the project-level cc-allow.local.toml. If
# invoked with no project root in the cwd ancestry, exits without
# touching anything (entries stay in settings.local.json until the
# user is in a project where they can be migrated).

set -euo pipefail
cat > /dev/null  # consume hook JSON

GLOBAL_SETTINGS="$HOME/.claude/settings.local.json"
PROJECT_SETTINGS=""
PROJECT_ROOT=""

dir="$(pwd)"
while [ "$dir" != "/" ]; do
  if [ -f "$dir/.claude/settings.local.json" ]; then
    if [ "$dir/.claude/settings.local.json" != "$GLOBAL_SETTINGS" ]; then
      PROJECT_SETTINGS="$dir/.claude/settings.local.json"
      PROJECT_ROOT="$dir"
    fi
    break
  fi
  dir="$(dirname "$dir")"
done

[ -z "$PROJECT_ROOT" ] && exit 0

MIGRATABLE_TYPES='Bash|Read|Edit|Write|Glob|Grep|WebFetch'

has_migratable() {
  [ -f "$1" ] || return 1
  jq -e --arg p "$MIGRATABLE_TYPES" '
    [.permissions.allow[]? // empty | select(test("^(\($p))\\("))]
    | length > 0
  ' "$1" > /dev/null 2>&1
}

need_global=false
need_project=false
if has_migratable "$GLOBAL_SETTINGS"; then need_global=true; fi
if has_migratable "$PROJECT_SETTINGS"; then need_project=true; fi
if [ "$need_global" = false ] && [ "$need_project" = false ]; then
  exit 0
fi

# --- Extractors (read settings.local.json, emit one value per line) ---

extract_bash() {
  jq -r '
    .permissions.allow[]? // empty
    | select(startswith("Bash("))
    | sub("^Bash\\("; "")
    | sub("[:)].*"; "")
    | split(" ")[0]
    | select(length > 0)
    | select(test("^[a-zA-Z./_~]"))
    | select(contains("=") | not)
    | select(test("[\"'\''\\\\]") | not)
    | select(test("^(do|done|for|while|if|then|else|elif|fi|case|esac|break|continue|in)$") | not)
  ' "$1" 2>/dev/null
}

extract_paths() {
  # $1 = file, $2 = tool name (Read|Edit|Write|Glob|Grep)
  jq -r --arg t "$2" '
    .permissions.allow[]? // empty
    | select(startswith($t + "("))
    | sub("^" + $t + "\\("; "")
    | sub("\\)$"; "")
    | select(length > 0)
    | sub("^/+"; "/")
  ' "$1" 2>/dev/null
}

extract_domains() {
  jq -r '
    .permissions.allow[]? // empty
    | select(startswith("WebFetch(domain:"))
    | sub("^WebFetch\\(domain:"; "")
    | sub("\\)$"; "")
    | select(length > 0)
  ' "$1" 2>/dev/null
}

# --- Idempotent re-read of existing cc-allow.local.toml entries ---

LOCAL_TOML="$PROJECT_ROOT/.config/cc-allow.local.toml"

parse_existing() {
  # $1 = section header (e.g. "[bash.allow]"), $2 = array key
  [ -f "$LOCAL_TOML" ] || return 0
  awk -v sec="$1" -v key="$2" '
    $0 == sec { in_sec = 1; next }
    /^\[/ { in_sec = 0 }
    in_sec && match($0, "^[ \t]*" key "[ \t]*=") {
      line = $0
      sub(/^[^=]*=[ \t]*\[/, "", line)
      sub(/\][ \t]*$/, "", line)
      n = split(line, parts, /[ \t]*,[ \t]*/)
      for (i = 1; i <= n; i++) {
        gsub(/^[ \t]*['"'"'"]|['"'"'"][ \t]*$/, "", parts[i])
        if (parts[i] != "") print parts[i]
      }
    }
  ' "$LOCAL_TOML"
}

# --- Per-section transforms ---

regex_escape_host() {
  # Escape regex metachars in a hostname for use in a re: pattern
  printf '%s' "$1" | sed 's/[].\\^$*+?()|{}[]/\\&/g'
}

prefix_path() { sed 's|^|path:|'; }

prefix_webfetch() {
  while IFS= read -r host; do
    [ -z "$host" ] && continue
    printf 're:^https?://%s(/|$)\n' "$(regex_escape_host "$host")"
  done
}

dedup_sort() { sort -u | sed '/^$/d'; }

collect_section() {
  # $1 = bash | read | edit | write | webfetch
  {
    case "$1" in
      bash)
        parse_existing "[bash.allow]" "commands"
        if [ "$need_global" = true ];  then extract_bash "$GLOBAL_SETTINGS";  fi
        if [ "$need_project" = true ]; then extract_bash "$PROJECT_SETTINGS"; fi
        ;;
      read)
        parse_existing "[read.allow]" "paths"
        if [ "$need_global" = true ]; then
          { extract_paths "$GLOBAL_SETTINGS" Read
            extract_paths "$GLOBAL_SETTINGS" Glob
            extract_paths "$GLOBAL_SETTINGS" Grep; } | prefix_path
        fi
        if [ "$need_project" = true ]; then
          { extract_paths "$PROJECT_SETTINGS" Read
            extract_paths "$PROJECT_SETTINGS" Glob
            extract_paths "$PROJECT_SETTINGS" Grep; } | prefix_path
        fi
        ;;
      edit|write)
        local tool
        if [ "$1" = edit ]; then tool=Edit; else tool=Write; fi
        parse_existing "[$1.allow]" "paths"
        if [ "$need_global" = true ];  then extract_paths "$GLOBAL_SETTINGS"  "$tool" | prefix_path; fi
        if [ "$need_project" = true ]; then extract_paths "$PROJECT_SETTINGS" "$tool" | prefix_path; fi
        ;;
      webfetch)
        parse_existing "[webfetch.allow]" "paths"
        if [ "$need_global" = true ];  then extract_domains "$GLOBAL_SETTINGS"  | prefix_webfetch; fi
        if [ "$need_project" = true ]; then extract_domains "$PROJECT_SETTINGS" | prefix_webfetch; fi
        ;;
    esac
  } | dedup_sort
}

bash_lines=$(collect_section bash)
read_lines=$(collect_section read)
edit_lines=$(collect_section edit)
write_lines=$(collect_section write)
webfetch_lines=$(collect_section webfetch)

# --- Render TOML ---

toml_array() {
  # Render values as TOML literal strings (single-quoted) so backslashes
  # in webfetch regex patterns (e.g. \. in escaped hostnames) pass through
  # without TOML escape-sequence interpretation.
  awk -v q="'" '
    NF == 0 { next }
    started { printf ", %s%s%s", q, $0, q; next }
    { printf "%s%s%s", q, $0, q; started = 1 }
  ' <<< "$1"
}

emit_section() {
  # $1 = section header, $2 = key, $3 = newline-delimited entries
  [ -z "$3" ] && return 0
  echo
  echo "$1"
  echo "$2 = [$(toml_array "$3")]"
}

if [ -n "$bash_lines$read_lines$edit_lines$write_lines$webfetch_lines" ]; then
  mkdir -p "$(dirname "$LOCAL_TOML")"
  {
    echo 'version = "2.0"'
    echo '# Auto-migrated from .claude/settings.local.json'
    echo '# To make permanent, add to .config/cc-allow.toml or ~/.config/cc-allow.toml.'
    emit_section "[bash.allow]"     "commands" "$bash_lines"
    emit_section "[read.allow]"     "paths"    "$read_lines"
    emit_section "[edit.allow]"     "paths"    "$edit_lines"
    emit_section "[write.allow]"    "paths"    "$write_lines"
    emit_section "[webfetch.allow]" "paths"    "$webfetch_lines"
  } > "$LOCAL_TOML"
fi

# --- Strip migrated entries from settings files ---

strip_entries() {
  local file="$1"
  [ -f "$file" ] || return 0
  local tmp
  tmp=$(mktemp)
  jq --arg p "$MIGRATABLE_TYPES" '
    if .permissions.allow then
      .permissions.allow |= [.[] | select(test("^(\($p))\\(") | not)]
    else . end
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

if [ "$need_global" = true ];  then strip_entries "$GLOBAL_SETTINGS";  fi
if [ "$need_project" = true ]; then strip_entries "$PROJECT_SETTINGS"; fi

exit 0
