# Branch Strategy

> CLAUDE.md §8에서 추출한 브랜치 전략 상세. 브랜치 종류 표·흐름·전체 규칙을 다룬다.
> CLAUDE.md에는 PR 생성 시 즉시 적용해야 하는 **Critical Rules 3개**만 인라인으로 남아 있다.

---

**`main` + `develop` 2-tier 모델.** 라이브 배포 안정성을 위해 프로덕션 코드와 통합 브랜치를 분리한다.

| 브랜치 | 역할 |
|---|---|
| `main` | 스토어에 출시된 프로덕션 코드. 릴리스 시점에 `v[pubspec version]` 태그를 찍음 |
| `develop` | 다음 릴리스 통합 브랜치. 모든 일반 PR의 base |
| `feature/*`, `fix/*`, `refactor/*`, `chore/*` | `develop`에서 분기 → `develop`으로 PR |
| `hotfix/*` | 프로덕션 긴급 수정. `main`에서 분기 → `main`과 `develop` 양쪽에 머지 |

### 흐름
```
feature/* ─PR→ develop ─PR→ main + tag(vX.Y.Z)
hotfix/*  ─PR→ main (+ develop 동기화 머지)
```

### 규칙 (전체)
- `main`, `develop`에 **직접 push 금지** — 항상 PR을 거친다.
- 모든 신규 PR의 base branch는 **`develop`** (hotfix 제외).
- 릴리스는 `develop` → `main` PR 머지 직후 `main`에서 `v[pubspec version]` 태그를 생성한다.
- 멀티 에이전트 워크플로의 Code Agent는 `develop`에서 feature 브랜치를 분기하고 PR base를 `develop`으로 설정한다.
- ⚠️ **release PR (`develop` → `main`) 머지 시 `--delete-branch` 옵션을 절대 사용하지 않는다** — `develop`은 long-lived 통합 브랜치로, 삭제 시 즉시 복구 + 모든 PR base 재설정이 필요해진다 (사고 사례: PR #49). feature PR (`feature/*` → `develop`) 머지에만 `--delete-branch` 사용.
