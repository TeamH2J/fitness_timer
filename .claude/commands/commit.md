---
description: "Analyze staged and unstaged git changes, auto-classify as feat:/fix:/chore:/refactor: etc., propose a conventional commit message, and execute git add + commit after confirmation. Use /commit to create a well-formatted commit."
allowed-tools: Bash
---

Run the following steps to create a git commit:

1. Run `git status` to see modified, added, and deleted files
2. Run `git diff HEAD` to understand what changed (also `git diff --cached` for staged files)
3. Run `git log --oneline -5` to understand the existing commit message style and language
4. Analyze the changes and determine the appropriate conventional commit type:
   - `feat:` — new feature or capability
   - `fix:` — bug fix
   - `refactor:` — code restructuring without behavior change
   - `chore:` — build, config, dependency, or tooling changes
   - `style:` — UI/visual changes, formatting
   - `docs:` — documentation only
5. Draft a concise commit message in the same language and style as recent commits
6. Show the user the proposed commit message and the list of files to be staged, then ask for confirmation or a revised message using AskUserQuestion
7. On approval: stage the relevant files by name (avoid `git add -A` or `git add .` to prevent accidentally including sensitive files) and run `git commit` with the approved message using a HEREDOC, appending:
   ```
   Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
   ```
8. Run `git status` to confirm the commit succeeded
