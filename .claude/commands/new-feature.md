Start a new Team Lead workflow. Generates a UUID, initializes `workflow_state.json`, and launches the full planning→trd→coding→review→merge pipeline.

## Usage

```
/new-feature <feature description>
```

Example:
```
/new-feature 홈 화면에 최근 검진 요약 카드 추가
```

## Steps

1. **Generate UUID:**
```bash
python -c "import uuid; print(uuid.uuid4())"
```

2. **Derive feature name** (kebab-case) from the user's description:
   - e.g. `"홈 화면에 최근 검진 요약 카드 추가"` → `home-recent-checkup-summary-card`

3. **Initialize `.claude/state/workflow_state.json`:**
```json
{
  "workflow_id": "<UUID>",
  "feature_name": "<feature-name-kebab-case>",
  "created_at": "<ISO 8601 now>",
  "updated_at": "<ISO 8601 now>",
  "current_stage": "planning",
  "branch_name": "feature/<feature-name-kebab-case>",
  "pr_number": null,
  "archive_path": null,
  "prd_iteration": 0,
  "max_prd_iterations": 3,
  "review_iteration": 0,
  "max_review_iterations": 3,
  "stages": {
    "planning": { "status": "pending", "prd_version": "v1.0", "input": { "requirements": "<user description>" }, "output": ".claude/outputs/PRD.md", "prd_feedback": null },
    "trd":      { "status": "pending", "output": ".claude/outputs/TRD.md" },
    "coding":   { "status": "pending", "pr_url": null, "review_feedback": null, "previous_feedback_items": null },
    "review":   { "status": "pending", "previous_feedback_items": null },
    "merge":    { "status": "pending" }
  }
}
```

4. **Print initialization summary:**
```
🚀 새 워크플로우 시작
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Feature  : <feature-name>
Branch   : feature/<feature-name>
ID       : <uuid>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Team Lead 에이전트를 실행하세요:
  claude --dangerously-skip-permissions --system-prompt .claude/agents/team-lead.md
그리고 다음 요구사항을 입력하세요:
  "<original user description>"
```

## Notes
- This skill only initializes the state file — it does NOT run the Team Lead automatically
- The user must launch Team Lead separately in a new session (or the Team Lead will detect the initialized state and continue)
- If `workflow_state.json` already exists and `current_stage` is not `"done"`, warn the user before overwriting:
  ```
  ⚠️  진행 중인 워크플로우가 있습니다 (current_stage: <stage>).
  덮어쓰면 기존 진행 상황이 사라집니다. 계속할까요? (yes/no)
  ```
