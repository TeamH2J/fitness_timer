---
name: flutter-check
description: Run `flutter analyze` in the `health_checkup_app/` directory and report errors/warnings clearly. Use proactively after any Dart/Flutter code change (per CLAUDE.md §7) and before suggesting a commit. Triggers when files under `health_checkup_app/lib/` or `health_checkup_app/test/` were edited.
---

# /flutter-check

Run `flutter analyze` in the `health_checkup_app/` directory and report the results clearly.

## When to use

- **Proactively**: after editing any `.dart` file under `health_checkup_app/`, before reporting work as complete or proposing a commit. CLAUDE.md §7 mandates this.
- **On request**: when the user asks to check analyzer status.

## Steps

1. Run:
   ```
   cd health_checkup_app && flutter analyze
   ```

2. Parse and display the output:
   - If **no issues found**: Print `✅ Flutter analyze: 이슈 없음`
   - If **issues found**: Print each issue with file path, line number, and message. Group by severity (error / warning / info). End with a summary count.

3. If there are **errors** (not warnings), also run:
   ```
   flutter build apk --debug 2>&1 | head -50
   ```
   to confirm whether the errors block compilation.

## Output Format

```
=== Flutter Analyze 결과 ===

✅ 이슈 없음
  또는
❌ 에러 N개 / ⚠️ 경고 N개 / ℹ️ 정보 N개

[에러 목록]
- lib/path/to/file.dart:42 — error message

[경고 목록]
- lib/path/to/file.dart:10 — warning message

컴파일 가능 여부: ✅ / ❌
```

## Notes
- Always run from the project root. The Flutter project is at `health_checkup_app/`.
- Do not auto-fix issues — report only. If the user wants fixes, they will ask separately.
