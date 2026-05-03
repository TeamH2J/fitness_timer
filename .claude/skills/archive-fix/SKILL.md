---
name: archive-fix
description: Scan the repository for misplaced PRD/TRD archive files and move them to the correct `docs/<YYYY-MM-DD>_<feature-name>/` location per CLAUDE.md §5. Use when noticing PRD/TRD files outside `docs/` (e.g. in `.claude/outputs/archive/`), or when the user asks to clean up archives.
---

# /archive-fix

Scan the repository for misplaced archive files and move them to the correct `docs/<YYYY-MM-DD>_<feature-name>/` location as specified in CLAUDE.md.

## When to use

- **Proactively**: when you spot a PRD.md or TRD.md outside the `docs/<date>_<feature>/` convention (e.g. lingering files in `.claude/outputs/archive/`).
- **On request**: when the user asks to fix or clean up archive locations.

## Steps

1. **Scan for misplaced archives** — Check these locations for PRD/TRD markdown files that do NOT belong there:
   - `.claude/outputs/archive/`
   - `.claude/outputs/*.md` (except PRD.md and TRD.md which are in-progress outputs)
   - Any other non-`docs/` location

2. **Read `.claude/state/workflow_state.json`** to get the correct `archive_path` for the current workflow.

3. For each misplaced file found:
   - Determine the correct target directory under `docs/`
   - If the target directory doesn't exist, create it with `mkdir -p`
   - Move the file with `mv` (or `cp` + verify + `rm`)

4. **Delete empty leftover directories** (e.g., `.claude/outputs/archive/` if now empty)

5. **Update `archive_path`** in `workflow_state.json` if it still points to the old location

6. Print a summary of what was moved

## Output Format

```
=== Archive Fix 결과 ===

🔍 스캔 결과:
  - .claude/outputs/archive/PRD.md  →  ⚠️ 잘못된 위치

📦 이동 작업:
  ✅ .claude/outputs/archive/PRD.md  →  docs/2026-04-12_my-feature/PRD_my-feature.md
  ✅ .claude/outputs/archive/TRD.md  →  docs/2026-04-12_my-feature/TRD_my-feature.md

🗑️  빈 디렉토리 삭제: .claude/outputs/archive/

📝 workflow_state.json 업데이트: archive_path → docs/2026-04-12_my-feature

✅ 완료 — 이동한 파일: 2개
```

If no misplaced files are found:
```
✅ 모든 아카이브가 docs/ 경로에 올바르게 위치합니다.
```

## Notes
- Do not touch `.claude/outputs/PRD.md` or `.claude/outputs/TRD.md` — these are live working files for the current workflow
- The correct archive structure is: `docs/<YYYY-MM-DD>_<feature-name>/PRD_<feature-name>.md` and `TRD_<feature-name>.md`
- Read-only scan first, then confirm before moving (if the user is present), or move directly in automated contexts
