---
name: pr
description: "PR lifecycle \u2014 push, open, status, feedback, merge. Pass a subcommand as the argument."
argument-hint: "<push|open|status|feedback|merge> [PR-NUMBER]"
---

# PR Lifecycle Skill

Manage the full pull request lifecycle from push to merge.

## Subcommand Dispatch

Parse the argument to determine the subcommand. If no argument is provided, show usage:

```
Usage: /pr <push|open|status|feedback|merge> [PR-NUMBER]
```

---

## `/pr push`

Push the current branch to the remote.

1. Check for uncommitted changes (staged or unstaged). If any exist, stage and commit using conventional commit format:
   - `type(scope): description` (lowercase, imperative mood, no period, under 72 chars)
   - Types: `feat`, `fix`, `refactor`, `docs`, `style`, `test`, `chore`, `perf`, `ci`
   - Body explains "why" not "what"
2. Detect whether a remote tracking branch exists:
   - First push: `git push -u origin <branch>`
   - Subsequent: `git push`
3. Report result (commits pushed, remote URL).

**Hard rules:**
- Never force push
- Never push to main/master
- Never use `--no-verify`

---

## `/pr open`

Push and create a PR.

1. Do everything `/pr push` does.
2. Determine the base branch: `git symbolic-ref refs/remotes/origin/HEAD --short 2>/dev/null || echo "origin/main"`
3. Generate PR title from branch commits (conventional commit style, under 70 chars).
4. Generate PR body using this template:

```
## Summary
- <1-3 bullet points describing the changes>

## Test plan
- <how to verify the changes>
```

5. Create the PR:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

6. Report the PR URL.

---

## `/pr status [N]`

Check a PR's health.

1. Resolve PR number:
   - If `N` provided, use it
   - Otherwise: `gh pr view --json number -q .number` (current branch's PR)
2. Fetch in parallel:
   - `gh pr view <N> --json title,state,reviewDecision,mergeStateStatus,statusCheckRollup,latestReviews`
   - `gh pr checks <N> --json name,bucket,state,workflow`
   - Unresolved review thread count via: `gh api graphql -f query='{ repository(owner:"<OWNER>",name:"<REPO>") { pullRequest(number:<N>) { reviewThreads(first:100) { nodes { isResolved } } } } }'`
3. Present a summary:
   - **Checks**: X passing, Y failing, Z pending (list failures by name)
   - **Reviews**: overall decision + individual reviewer states
   - **Unresolved threads**: count
   - **Verdict**: "Ready to merge" or "Blocked by: ..." (list blockers)

---

## `/pr feedback [N]`

Address unresolved review feedback.

1. Resolve PR number (same as `/pr status`).
2. Fetch ONLY unresolved review threads via GraphQL:

```graphql
{
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: <N>) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          path
          line
          comments(first: 10) {
            nodes {
              body
              author { login }
            }
          }
        }
      }
    }
  }
}
```

3. Filter to `isResolved == false` only. If none: report "No unresolved feedback" and stop.
4. For each unresolved thread:
   - Read the referenced file and line
   - Understand the feedback
   - If feedback is ambiguous, ask the user instead of guessing
   - Make the code change
5. Commit all changes: `fix: address PR review feedback`
6. Push (skip only if the user explicitly asked not to push).
7. Resolve each addressed thread via GraphQL mutation:

```graphql
mutation {
  resolveReviewThread(input: { threadId: "<THREAD_ID>" }) {
    thread { isResolved }
  }
}
```

8. **NEVER post comments or replies** -- only resolve threads.
9. Report: X threads addressed, Y skipped (with reasons for skips).

---

## `/pr merge [N]`

Rewrite PR body, then squash-merge with a clean commit message.

1. Resolve PR number (same as `/pr status`).
2. **Pre-flight check** (same as `/pr status`):
   - All checks passing
   - Reviews approved
   - No unresolved threads
   - If blocked: report blockers and stop. Do not merge.
3. Fetch PR details: `gh pr view <N> --json title,body,commits,files`
4. Read full diff: `gh pr diff <N>`
5. **Rewrite PR body** to reflect the final state of the changes:
   - Keep existing structure and sections
   - Minimally update to match actual changes (scope changes, additional files touched, etc.)
   - Remove template placeholder text
   - Err on the side of fewer changes, not more
6. Update PR body: `gh pr edit <N> --body "..."`
7. Extract owner/repo: `gh repo view --json nameWithOwner -q .nameWithOwner`
8. Squash merge using the rewritten body as the commit message:

```bash
gh pr merge <N> --squash --subject "<PR title>" --body "<rewritten body>" --delete-branch
```

9. Report: merged commit SHA (from `gh pr view <N> --json mergeCommit`).

---

## Shared Rules (apply to ALL subcommands)

- **Never force push.** If push fails, report the error and stop.
- **Never push to main/master.** If the current branch is main or master, refuse and explain.
- **Never use `--admin`** to bypass branch protection.
- **Never post PR comments or replies.** Do not use `gh pr comment`, `gh pr review --comment`, or the GitHub API to post text on PRs. The only allowed post-push PR mutation is `resolveReviewThread`.
- **Never read or consider resolved/closed threads.** Filter to unresolved only.
- **Never use `--no-verify`** to skip git hooks.
- If any step fails, report the error and stop. Do not retry automatically.
