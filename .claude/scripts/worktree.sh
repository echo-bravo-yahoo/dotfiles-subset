#!/usr/bin/env bash
set -euo pipefail

# worktree.sh - Manage git worktrees with context tracking
#
# Usage:
#   worktree.sh new <branch-name> [--base <ref>] [--jira <TICKET>] [--conversation <id>] [--description <text>]
#   worktree.sh list
#   worktree.sh cleanup [--force]

WORKTREES_DIR=".worktrees"
CONTEXT_FILE=".claude-context.toml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

error() { echo -e "${RED}error:${NC} $1" >&2; exit 1; }
warn() { echo -e "${YELLOW}warning:${NC} $1" >&2; }
info() { echo -e "${CYAN}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }

# Sanitize branch name to directory name (lowercase, slashes to dashes)
sanitize_dir_name() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr '/' '-'
}

# Parse TOML context file and output fields
parse_context() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo ""
        echo ""
        echo ""
        echo ""
        echo ""
        return
    fi
    python3 -c "
import tomllib, sys
try:
    with open(sys.argv[1], 'rb') as f:
        data = tomllib.load(f)
    ctx = data.get('context', {})
    print(ctx.get('jira', ''))
    print(ctx.get('pr', ''))
    print(ctx.get('branch', ''))
    print(ctx.get('conversation', ''))
    desc = ctx.get('description', '')
    # Truncate description for display
    print(desc[:60].replace('\n', ' '))
except Exception:
    print('')
    print('')
    print('')
    print('')
    print('')
" "$file"
}

# Write TOML context file
write_context() {
    local file="$1"
    local jira="${2:-}"
    local pr="${3:-}"
    local branch="${4:-}"
    local conversation="${5:-}"
    local description="${6:-}"

    cat > "$file" << EOF
[context]
jira = "$jira"
pr = "$pr"
branch = "$branch"
conversation = "$conversation"
description = """
$description
"""
EOF
}

cmd_new() {
    local branch_name=""
    local base_ref="origin/main"
    local jira=""
    local conversation=""
    local description=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --base)
                base_ref="$2"
                shift 2
                ;;
            --jira)
                jira="$2"
                shift 2
                ;;
            --conversation)
                conversation="$2"
                shift 2
                ;;
            --description)
                description="$2"
                shift 2
                ;;
            -*)
                error "Unknown option: $1"
                ;;
            *)
                if [[ -z "$branch_name" ]]; then
                    branch_name="$1"
                else
                    error "Unexpected argument: $1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$branch_name" ]]; then
        error "Branch name is required.\nUsage: worktree.sh new <branch-name> [--base <ref>] [--jira <TICKET>] [--conversation <id>] [--description <text>]"
    fi

    local dir_name
    dir_name=$(sanitize_dir_name "$branch_name")
    local worktree_path="$WORKTREES_DIR/$dir_name"

    # Validate: branch must not already exist
    if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
        error "Branch '$branch_name' already exists. Use a different name or delete the existing branch."
    fi

    # Validate: worktree directory must not exist
    if [[ -d "$worktree_path" ]]; then
        error "Worktree directory '$worktree_path' already exists. Remove it first or use a different branch name."
    fi

    # Create worktrees directory if needed
    mkdir -p "$WORKTREES_DIR"

    # Fetch latest from origin
    info "Fetching from origin..."
    git fetch origin

    # Create branch from base
    info "Creating branch '$branch_name' from '$base_ref'..."
    git branch "$branch_name" "$base_ref"

    # Create worktree
    info "Creating worktree at '$worktree_path'..."
    git worktree add "$worktree_path" "$branch_name"

    # Symlink node_modules
    local abs_node_modules
    abs_node_modules="$(pwd)/node_modules"
    if [[ -d "$abs_node_modules" ]]; then
        info "Symlinking node_modules..."
        ln -s "$abs_node_modules" "$worktree_path/node_modules"
    else
        warn "node_modules not found in parent directory. You may need to run 'npm run npmi' in the worktree."
    fi

    # Verify husky hook exists
    if [[ -x ".husky/pre-commit" ]]; then
        info "Husky pre-commit hook verified."
    else
        warn ".husky/pre-commit hook not found or not executable."
    fi

    # Write context file
    write_context "$worktree_path/$CONTEXT_FILE" "$jira" "" "$branch_name" "$conversation" "$description"
    info "Created context file at $worktree_path/$CONTEXT_FILE"

    # Output results
    echo ""
    success "Worktree created successfully!"
    echo ""
    echo "Path: $(cd "$worktree_path" && pwd)"
    echo "Branch: $branch_name"
    [[ -n "$jira" ]] && echo "Jira: $jira"
    echo ""
    echo "To switch to this worktree:"
    echo "  cd $(cd "$worktree_path" && pwd)"
}

cmd_list() {
    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "No worktrees directory found."
        return 0
    fi

    # Header
    printf "%-25s %-30s %-12s %-8s %s\n" "WORKTREE" "BRANCH" "JIRA" "PR" "DESCRIPTION"
    printf "%-25s %-30s %-12s %-8s %s\n" "--------" "------" "----" "--" "-----------"

    # Get git worktree list for cross-reference
    local worktree_info
    worktree_info=$(git worktree list --porcelain 2>/dev/null || true)

    # Enumerate worktree directories
    for worktree_dir in "$WORKTREES_DIR"/*/; do
        [[ -d "$worktree_dir" ]] || continue

        local dir_name
        dir_name=$(basename "$worktree_dir")

        # Skip if this has nested worktrees (non-empty .worktrees dir)
        if [[ -d "$worktree_dir/.worktrees" ]] && [[ -n "$(ls -A "$worktree_dir/.worktrees" 2>/dev/null)" ]]; then
            continue
        fi

        local context_file="$worktree_dir$CONTEXT_FILE"
        local jira="-" pr="-" branch="-" conversation="" description="-"

        if [[ -f "$context_file" ]]; then
            local parsed
            parsed=$(parse_context "$context_file")
            jira=$(echo "$parsed" | sed -n '1p')
            pr=$(echo "$parsed" | sed -n '2p')
            branch=$(echo "$parsed" | sed -n '3p')
            conversation=$(echo "$parsed" | sed -n '4p')
            description=$(echo "$parsed" | sed -n '5p')

            [[ -z "$jira" ]] && jira="-"
            [[ -z "$pr" ]] && pr="-"
            [[ -z "$branch" ]] && branch="-"
            [[ -z "$description" ]] && description="-"
        fi

        # If branch not in context, try to get it from git
        if [[ "$branch" == "-" ]]; then
            local git_branch
            git_branch=$(cd "$worktree_dir" && git branch --show-current 2>/dev/null || echo "-")
            branch="$git_branch"
        fi

        printf "%-25s %-30s %-12s %-8s %s\n" "$dir_name" "$branch" "$jira" "$pr" "$description"
    done
}

cmd_cleanup() {
    local force=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                force=true
                shift
                ;;
            --dry-run)
                # dry-run is the default, just ignore
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done

    if [[ ! -d "$WORKTREES_DIR" ]]; then
        echo "No worktrees directory found."
        return 0
    fi

    local to_cleanup=()
    local cleanup_info=()

    # Enumerate worktree directories
    for worktree_dir in "$WORKTREES_DIR"/*/; do
        [[ -d "$worktree_dir" ]] || continue

        local dir_name
        dir_name=$(basename "$worktree_dir")

        # Skip if this has nested worktrees (non-empty .worktrees dir)
        if [[ -d "$worktree_dir/.worktrees" ]] && [[ -n "$(ls -A "$worktree_dir/.worktrees" 2>/dev/null)" ]]; then
            continue
        fi

        local context_file="$worktree_dir$CONTEXT_FILE"
        local pr="" branch=""

        if [[ -f "$context_file" ]]; then
            local parsed
            parsed=$(parse_context "$context_file")
            pr=$(echo "$parsed" | sed -n '2p')
            branch=$(echo "$parsed" | sed -n '3p')
        fi

        # If no branch in context, get from git
        if [[ -z "$branch" ]]; then
            branch=$(cd "$worktree_dir" && git branch --show-current 2>/dev/null || echo "")
        fi

        # Skip if no PR to check
        if [[ -z "$pr" || "$pr" == "-" ]]; then
            continue
        fi

        # Extract PR number (handle #123 or just 123)
        local pr_number="${pr#\#}"

        # Check PR status
        local pr_state
        pr_state=$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null || echo "ERROR")

        if [[ "$pr_state" == "MERGED" || "$pr_state" == "CLOSED" ]]; then
            to_cleanup+=("$dir_name")
            cleanup_info+=("$dir_name|$branch|$pr|$pr_state")
        fi
    done

    if [[ ${#to_cleanup[@]} -eq 0 ]]; then
        echo "No worktrees eligible for cleanup (no merged/closed PRs found)."
        return 0
    fi

    echo "Worktrees eligible for cleanup:"
    echo ""
    printf "%-25s %-30s %-8s %s\n" "WORKTREE" "BRANCH" "PR" "STATE"
    printf "%-25s %-30s %-8s %s\n" "--------" "------" "--" "-----"
    for info in "${cleanup_info[@]}"; do
        IFS='|' read -r dir_name branch pr pr_state <<< "$info"
        printf "%-25s %-30s %-8s %s\n" "$dir_name" "$branch" "$pr" "$pr_state"
    done
    echo ""

    if [[ "$force" != true ]]; then
        warn "Dry-run mode. Run with --force to actually delete these worktrees."
        return 0
    fi

    # Actually delete
    for info in "${cleanup_info[@]}"; do
        IFS='|' read -r dir_name branch pr pr_state <<< "$info"
        local worktree_path="$WORKTREES_DIR/$dir_name"

        info "Removing worktree '$dir_name'..."

        # Remove worktree
        git worktree remove "$worktree_path" --force 2>/dev/null || {
            warn "Failed to remove worktree '$worktree_path' via git, removing directory manually..."
            rm -rf "$worktree_path"
            git worktree prune
        }

        # Delete branch
        if [[ -n "$branch" ]]; then
            if [[ "$pr_state" == "MERGED" ]]; then
                git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || warn "Could not delete branch '$branch'"
            else
                git branch -D "$branch" 2>/dev/null || warn "Could not delete branch '$branch'"
            fi
        fi

        success "Removed worktree '$dir_name' and branch '$branch'"
    done
}

show_usage() {
    cat << 'EOF'
worktree.sh - Manage git worktrees with context tracking

Usage:
  worktree.sh new <branch-name> [--base <ref>] [--jira <TICKET>] [--conversation <id>] [--description <text>]
  worktree.sh list
  worktree.sh cleanup [--force]

Commands:
  new       Create a new worktree with branch and context file
  list      List all worktrees with their context
  cleanup   Remove worktrees with merged/closed PRs (dry-run by default)

Options for 'new':
  --base <ref>           Base ref for branch (default: origin/main)
  --jira <TICKET>        Jira ticket ID to associate
  --conversation <id>    Claude conversation ID
  --description <text>   Description of the work

Options for 'cleanup':
  --force                Actually delete (default is dry-run)
  --dry-run              Show what would be deleted (default)

Examples:
  worktree.sh new fix/mac-12345 --jira MAC-12345 --description "Fix button alignment"
  worktree.sh list
  worktree.sh cleanup
  worktree.sh cleanup --force
EOF
}

# Main
if [[ $# -eq 0 ]]; then
    show_usage
    exit 0
fi

command="$1"
shift

case "$command" in
    new)
        cmd_new "$@"
        ;;
    list)
        cmd_list "$@"
        ;;
    cleanup)
        cmd_cleanup "$@"
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        error "Unknown command: $command\nRun 'worktree.sh help' for usage."
        ;;
esac
