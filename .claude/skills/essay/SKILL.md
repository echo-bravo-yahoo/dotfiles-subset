---
name: essay
description: Begins work on a new task. Use when instructed to start something from scratch.
allowed-tools: Bash(git worktree list *), Bash(git worktree add *), Bash(git branch *), Bash(echo *), Bash(pbcopy)
disable-model-invocation: true
---

Start by taking these actions:

1. If this was run as a command, all text after the command is a description of the feature the user wants to explore / work on. If it contains no whitespace and is either kebab-case, snake_case, or camelCase, use it literally as the description of the task they want to do. If not, generate a short kebab-case description of their task.
2. Create a new git branch off `origin/main`. The working index may be dirty when you start this skill - that's ok. Consider a command like `git branch echobravoyahoo/a-short-task-description`. Always start the branch name with the username "echobravoyahoo/".
3. Create a new git worktree with the same name as the branch, without the username. In the previous example, it would be named `a-short-task-description`. Consider a command like `git worktree add ../a-short-task-description echobravoyahoo/a-short-task-description`.
4. Generate the command to move to that directory and run claude code. Consider a command like `cd ../a-short-task-description && claude`.
5. Copy that command to the system clipboard using `pbcopy`.
6. Instruct the user to paste and run the command.
7. Identify the current session's process ID (pid). You will not be able to use a simple strategy (e.g., `Bash(echo $$)`) because that runs in a subagent in another process with its own pid. Find another way to identify this process's pid.
8. Kill the process with this process's pid. I understand that it will end this conversation. I insist that you do it anyway.
