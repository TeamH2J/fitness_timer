# Codebase Map — account_book Flutter 프로젝트

> AI 에이전트 / 신규 컨트리뷰터를 위한 폴더·도메인 navigation 맵.
> 클래스/파일을 찾거나 "기능 X를 어디에 추가하지?" 같은 질문에 빠르게 답하기 위한 문서.

## Overview

가계부 + 포트폴리오 + 주식 통합 개인 재무 앱 (Android/iOS/Windows). Flutter + Provider + Isar (로컬 ORM) + Supabase (동기화).

**3개 핵심 도메인**: 가계부(account_book) / 포트폴리오(portfolio) / 주식(stocks). 보조 영역: 통계, 설정.

**최근 분해 라운드 결과** (2026-05 분해/위생 PR #29-#44):
- `account_book_page.dart`: 1,824 → 199줄 (-89%)
- `target_allocation_tab.dart`: 2,434 → 281줄 (-88%)
- `portfolio_provider.dart`: 1,074 → 544줄 (-49%)
- `flutter analyze`: 0 issues / 0 warnings / 0 errors (info 포함)

**이 문서 사용법**: §2 트리로 위치 파악 → §3 도메인 맵으로 의존성 확인 → §5 의사결정 가이드로 신규 코드 위치 결정 → §6 Lookup 표로 클래스명 ↔ 파일 매핑.

---

## 2. Directory Tree

---

## 3. Domain Map

---

## 4. Naming & Pattern Conventions

---

## 5. "어디에 추가할까?" 의사결정 가이드

---

## 6. 핵심 Class ↔ File Lookup

---

## 7. 분해 히스토리 메모

---

## 8. 변경 시 주의사항

- **build_runner 생성물** (`*.g.dart`): 직접 수정 금지. 모델 변경 시 `dart run build_runner build` 재생성.
- **CI 검증**: `flutter analyze --no-fatal-infos` 0 errors / 0 warnings + `flutter test` 통과가 PR 머지 조건.
- **Surgical change 원칙** (CLAUDE.md §3): 한 PR에서 한 책임만. 무관한 lint/스타일 동시 정리 금지(별도 PR).
- **Dialog 추출 시 본문 character-for-character 동일성**: 분해 PR들은 모두 본문을 글자 단위 동일하게 유지하면서 클래스/함수 추출만 수행. 신규 추출 PR도 동일 원칙.
