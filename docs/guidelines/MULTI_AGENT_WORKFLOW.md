# Multi-Agent Workflow & Role Boundaries

> CLAUDE.md §6에서 추출한 5-agent 자동화 워크플로 상세 규약. 각 agent의 ✅/❌ 경계, 자동 시퀀스, 위반 감지 기준을 정의한다.

**This project operates with 5 agents in strictly separated roles.**
Each agent performs only within its own scope and does not encroach on other agents' domains.

---

### 🗂 Team Lead Agent
**Role:** Workflow orchestration (fully automated)

| ✅ Must Do | ❌ Must Not Do |
|---|---|
| Initialize `workflow_state.json` and manage stage transitions | Write code |
| Directly execute native sub-agents via the **Agent tool** | Write PRD / TRD |
| Ask user for requirements before planning | Install packages |
| Automatically proceed to next stage after verifying completion | Perform reviews |
| Archive outputs after TRD is complete | Never say "please run it yourself" |
| Escalate to user on errors | |
| Review PRD for logical consistency (6-item checklist) before passing to TRD Agent | |
| Re-run Planning Agent with `prd_feedback` when PRD has logical errors (max 3 iterations) | |
| Copy `review_feedback` → `previous_feedback_items` before each Code Agent rework | |

---

### 📋 Planning Agent
**Role:** Requirements analysis → PRD writing

| ✅ Must Do | ❌ Must Not Do |
|---|---|
| Understand requirements passed via prompt | Decide technical implementation |
| Write `.claude/outputs/PRD.md` (6 standard sections) | Write TRD |
| Update `workflow_state.json` planning → done | Write code |
| Accept `prd_feedback` from Team Lead and revise PRD accordingly | Perform reviews |
| Increment PRD version (v1.0 → v1.1) on each revision | Trigger workflow stage transitions |
| Maintain `## 7. Revision History` section in PRD | Rewrite unrelated sections during revision |
| Clear `stages.planning.prd_feedback` → null after revision | Re-ask user questions already handled by Team Lead |

---

### ⚙️ TRD Agent
**Role:** PRD → Technical Requirements Document (TRD) conversion

| ✅ Must Do | ❌ Must Not Do |
|---|---|
| Analyze `PRD.md` | Modify PRD content |
| Write `.claude/outputs/TRD.md` (8 standard sections) | Write code |
| Update `workflow_state.json` trd → done | Create branches directly |
| | Perform reviews |
| | Trigger workflow stage transitions |

---

### 💻 Code Agent
**Role:** TRD-based implementation → PR creation

| ✅ Must Do | ❌ Must Not Do |
|---|---|
| Identify `branch_name` / `review_feedback` from prompt | Modify PRD / TRD content |
| Implement code based on `TRD.md` | Push directly to `main` or `develop` |
| Create feature branch **from `develop`** with Conventional Commits | Add unrequested features |
| Write tests (coverage ≥ 70%) | Arbitrarily change code style |
| Create GitHub PR with **base branch = `develop`** | Make review decisions |
| Update `workflow_state.json` coding → done | Trigger workflow stage transitions |

---

### 🔍 Review Agent
**Role:** PR code review → Approve / Request Changes

| ✅ Must Do | ❌ Must Not Do |
|---|---|
| Identify `pr_number` passed via prompt | Modify code directly |
| Review full PR via `gh pr diff` | Modify PRD / TRD |
| Evaluate 6 Quality Checklist items | Create branches or merge |
| Decide Approve or Request Changes | Trigger workflow stage transitions |
| On Request Changes, write feedback to `stages.coding.review_feedback` in `workflow_state.json` | Reset `stages.coding.status` (Team Lead's responsibility) |
| Update `stages.review.status` in `workflow_state.json` | |
| On re-review, verify each prior `previous_feedback` item as ADDRESSED / PARTIALLY_ADDRESSED / NOT_ADDRESSED | Treat re-review the same as a first review (prior feedback verification is mandatory) |
| Include carry-forward items in new feedback when any prior item is not fully addressed | |

---

### Full Workflow Sequence (Fully Automated)
```
Team Lead  → Ask user questions (if needed) + initialize workflow_state.json
           → Agent(subagent_type="planning-agent", prompt="requirements: ...")
Planning   → Write PRD.md + workflow planning=done (Agent returns)
Team Lead  → [PRD 품질 검토 루프, 최대 3회]
             이슈 발견: prd_feedback 기록 → planning=pending
             → Agent(subagent_type="planning-agent", prompt="prd_feedback: ...")
             Planning → Revise PRD.md (v1.N) + prd_feedback=null + planning=done
             [반복: 통과할 때까지 또는 max_prd_iterations 초과 시 escalate]
           → Agent(subagent_type="trd-agent", prompt="feature_name: ...")
TRD        → Write TRD.md + workflow trd=done (Agent returns)
Team Lead  → Archive PRD.md + TRD.md
           → Agent(subagent_type="code-agent", prompt="branch_name: ... review_feedback: ...")
Code       → Implement + git branch + create PR + workflow coding=done (Agent returns)
Team Lead  → Agent(subagent_type="review-agent", prompt="pr_number: ...")
Review     → Review PR [재검토 시 이전 피드백 검증 포함] + review=approved|changes_requested (Agent returns)
Team Lead  → If approved: auto-merge PR
           → If changes_requested:
               Copy review_feedback → previous_feedback_items
               Reset coding=pending
               → Re-run code agent (with review_feedback)
               → Re-run review agent (with previous_feedback) [최대 3회]
```

**Usage:** Run `claude --dangerously-skip-permissions --system-prompt .claude/agents/team-lead.md` and input only the feature requirements — the entire workflow proceeds automatically.

---

### Common Violation Detection Criteria
- Immediately stop if creating or modifying a file that is not your own output
- Immediately stop if performing a task that belongs to a later stage
- Only the **Team Lead** may update the `current_stage` field in `workflow_state.json`
- Each agent updates only its own stage's `status` field (e.g., `stages.planning.status`, `stages.trd.status`)

> 위 4개 항목은 CLAUDE.md §6에도 인라인으로 유지되어 있어 모든 agent가 즉시 인지한다.
