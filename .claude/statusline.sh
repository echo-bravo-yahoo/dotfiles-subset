#!/bin/bash
# Claude Code status line script
# Sources session cache from c CLI, plus session data from stdin

set -euo pipefail

# Read JSON from stdin
INPUT=$(cat)

# Use session's working directory for git commands
SESSION_CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
if [[ -n "$SESSION_CWD" ]]; then
    cd "$SESSION_CWD"
fi

# Session cost from Claude
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0')
COST_FMT=$(printf '$%.2f' "$COST")

# Context usage
PCT=$(echo "$INPUT" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# Session ID for c status cache
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')

# OSC 8 hyperlink helper: link "url" "display_text"
link() {
    printf '\e]8;;%s\e\\%s\e]8;;\e\\' "$1" "$2"
}

# 256-color foreground helper
c() { printf '\e[38;5;%sm' "$1"; }
r() { printf '\e[0m'; }

# Build output parts
PARTS=()

# Source session cache from c CLI
BRANCH="" PR="" JIRA="" REPO="" JIRA_BASE="" WORKTREE="" WORKTREE_PATH=""
C_HOME="${C_HOME:-$HOME/.c}"
if [[ -n "$SESSION_ID" && -f "$C_HOME/status/$SESSION_ID" ]]; then
    . "$C_HOME/status/$SESSION_ID"
fi

# Shorten path with color: ~/w/project for ~/workspace/project
# ~ and last part: blue bold; middle parts: grey; slashes: blue unbold
shorten_path() {
    local p="$1"
    local blue_bold='\e[1;38;5;39m'
    local blue='\e[0;38;5;39m'
    local grey='\e[0;38;5;244m'
    local reset='\e[0m'
    p="${p/#$HOME/~}"
    local IFS='/'
    local parts=($p)
    local last=$((${#parts[@]} - 1))
    local result=""
    for i in "${!parts[@]}"; do
        if [[ $i -eq $last ]]; then
            result+="${blue_bold}${parts[$i]}${reset}"
        elif [[ "${parts[$i]}" == "~" ]]; then
            result+="${blue_bold}~${blue}/"
        else
            result+="${grey}${parts[$i]:0:1}${blue}/"
        fi
    done
    printf '%b' "$result"
}

# Determine directory name and worktree status
IS_WORKTREE=false
if git rev-parse --is-inside-work-tree &>/dev/null; then
    MAIN_WORKTREE=$(git worktree list | head -1 | awk '{print $1}')
    if [[ "$(git rev-parse --show-toplevel)" != "$MAIN_WORKTREE" ]]; then
        IS_WORKTREE=true
        DIR_NAME=$(shorten_path "$MAIN_WORKTREE")
    else
        DIR_NAME=$(shorten_path "$PWD")
    fi
else
    DIR_NAME=$(shorten_path "$PWD")
fi

# Git status: Dir (Worktree) Branch ⇡N ⇣N *N +N !N ?N
GIT_STATUS=$(git status --porcelain=v2 --branch 2>/dev/null || true)
if [[ -n "$GIT_STATUS" ]]; then
    if [[ -z "$BRANCH" ]]; then
        BRANCH=$(echo "$GIT_STATUS" | sed -n 's/^# branch.head //p')
    fi

    GIT_SECTION=""

    # Directory name (linked to GitHub if REPO set)
    if [[ -n "$REPO" ]]; then
        GIT_SECTION+="$(link "https://github.com/$REPO" "$DIR_NAME")"
    else
        GIT_SECTION+="$DIR_NAME"
    fi

    # Worktree prefix (parenthesized)
    if [[ "$IS_WORKTREE" = true ]]; then
        if [[ -n "$WORKTREE" && -n "$WORKTREE_PATH" ]]; then
            GIT_SECTION+=" $(c 244)$(link "file://$WORKTREE_PATH" "($WORKTREE)")$(r)"
        elif [[ -n "$WORKTREE" ]]; then
            GIT_SECTION+=" $(c 244)($WORKTREE)$(r)"
        else
            WT_NAME=$(basename "$(git rev-parse --show-toplevel)")
            GIT_SECTION+=" $(c 244)($WT_NAME)$(r)"
        fi
    fi

    # Branch name
    GIT_SECTION+=" $(c 76)${BRANCH}$(r)"

    # Worktree landed indicator: clean worktree fully merged into main
    # Ordered cheapest-first: variable check → regex on existing string → git command
    if [[ "$IS_WORKTREE" = true ]] \
       && ! [[ "$GIT_STATUS" =~ $'\n'[12?]' ' ]] \
       && git merge-base --is-ancestor HEAD main 2>/dev/null; then
        GIT_SECTION+=" $(c 244)∴$(r)"
    fi

    # Parse status indicators
    AHEAD=0 BEHIND=0 STAGED=0 UNSTAGED=0 UNTRACKED=0
    while IFS= read -r line; do
        case "$line" in
            "# branch.ab "*)
                AHEAD="${line#*+}"; AHEAD="${AHEAD%% *}"
                BEHIND="${line#*-}"; BEHIND="${BEHIND%% *}"
                ;;
            "1 "*|"2 "*)
                # XY status: X=staged, Y=unstaged; '.' means unchanged
                XY="${line#* }"      # skip the type prefix
                XY="${XY%% *}"       # isolate XY field
                [[ "${XY:0:1}" != "." ]] && ((STAGED++))
                [[ "${XY:1:1}" != "." ]] && ((UNSTAGED++))
                ;;
            "? "*) ((UNTRACKED++)) ;;
        esac
    done <<< "$GIT_STATUS"

    STASH=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

    [[ "$AHEAD" -gt 0 ]]     && GIT_SECTION+=" $(c 76)⇡${AHEAD}$(r)"
    [[ "$BEHIND" -gt 0 ]]    && GIT_SECTION+=" $(c 76)⇣${BEHIND}$(r)"
    [[ "$STASH" -gt 0 ]]     && GIT_SECTION+=" $(c 76)*${STASH}$(r)"
    [[ "$STAGED" -gt 0 ]]    && GIT_SECTION+=" $(c 178)+${STAGED}$(r)"
    [[ "$UNSTAGED" -gt 0 ]]  && GIT_SECTION+=" $(c 178)!${UNSTAGED}$(r)"
    [[ "$UNTRACKED" -gt 0 ]] && GIT_SECTION+=" $(c 39)?${UNTRACKED}$(r)"

    PARTS+=("$GIT_SECTION")
else
    # Non-git fallback: just the directory name
    PARTS+=("$DIR_NAME")
fi

# Session ID — first segment, green normally, yellow+asterisk for ephemeral
if [[ -n "$SESSION_ID" ]]; then
    SHORT="${SESSION_ID%%-*}"
    if [[ "${EPHEMERAL:-}" == "1" ]]; then
        PARTS+=("$(c 178)${SHORT}$(r)$(c 135)*$(r)")
    else
        PARTS+=("$(c 76)${SHORT}$(r)")
    fi
fi

# PR (link to GitHub PR)
if [[ -n "$PR" ]]; then
    PR_NUM="${PR##*/}"
    PARTS+=("$(link "$PR" "PR#$PR_NUM")")
fi

# Jira ticket (link to Jira)
if [[ -n "$JIRA" && -n "$JIRA_BASE" ]]; then
    JIRA_URL="$JIRA_BASE/browse/$JIRA"
    PARTS+=("$(link "$JIRA_URL" "$JIRA")")
elif [[ -n "$JIRA" ]]; then
    PARTS+=("$JIRA")
fi

# Context % (color by threshold — auto-compaction at ~70%)
if [[ "$PCT" -ge 60 ]]; then
    PCT_COLOR=196  # red — compaction imminent
elif [[ "$PCT" -ge 33 ]]; then
    PCT_COLOR=178  # yellow — past a third
else
    PCT_COLOR=76   # green — plenty of room
fi
PARTS+=("$(c $PCT_COLOR)${PCT}%$(r)")

# Cost — Pro/Max: replace with 5h rate limit as $XX%; API billing: show dollar cost
RL_PCT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [[ -n "$RL_PCT" ]]; then
    RL_INT=$(printf '%.0f' "$RL_PCT")
    if [[ "$RL_INT" -ge 85 ]]; then
        RL_COLOR=196
    elif [[ "$RL_INT" -ge 75 ]]; then
        RL_COLOR=178
    else
        RL_COLOR=76
    fi
    PARTS+=("$(c $RL_COLOR)\$${RL_INT}%$(r)")
else
    PARTS+=("$COST_FMT")
fi

# Join with separator
printf '%s' "${PARTS[0]}"
printf ' | %s' "${PARTS[@]:1}"
echo
