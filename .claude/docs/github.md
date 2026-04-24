# GitHub CLI & API

## Reading PR Feedback

GitHub has two separate comment APIs for pull requests. Always check both when reading PR feedback:

| Endpoint | What it returns | `gh` equivalent |
|----------|----------------|-----------------|
| `GET /repos/{owner}/{repo}/pulls/{pr}/comments` | Inline review comments (on specific lines of code) | `gh api repos/o/r/pulls/N/comments` |
| `GET /repos/{owner}/{repo}/issues/{pr}/comments` | General PR comments (not attached to specific lines) | `gh api repos/o/r/issues/N/comments` |
| `GET /repos/{owner}/{repo}/pulls/{pr}/reviews` | Review summaries (approve/request-changes/comment) | `gh api repos/o/r/pulls/N/reviews` |

Bot reviewers (e.g., `claude[bot]`, `github-actions[bot]`) often post general comments via the issues endpoint rather than inline review comments. Missing the issues endpoint means missing their feedback entirely.

## Remote URL / Push Auth

If `git push` fails with a credentials error, check the remote URL:

```bash
git remote -v
```

If it shows an `https://` URL, swap it to the SSH equivalent — SSH keys are already configured:

```bash
git remote set-url origin git@<provider>:<owner>/<repo>.git
# e.g. git remote set-url origin git@github.com:echo-bravo-yahoo/c.git
```

HTTPS remotes require interactive credential input that isn't available in this environment. SSH remotes work without any extra auth.
