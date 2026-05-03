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

```
lib/
├── main.dart                              # 앱 진입점 (mainCommon 호출)
├── main_dev.dart, main_prod.dart            # 환경별 진입점
├── my_home_page.dart                      # 메인 5-탭 네비게이션 (가계부/포트폴리오/주식/통계/설정)
│
├── pages/                                 # 화면 단위
│   ├── account_book_page.dart             # 가계부 메인 페이지
│   ├── account_book/
│   │   ├── widgets/                       # 5개 위젯 (StatelessWidget)
│   │   └── dialogs/                       # 13개 다이얼로그
│   │
│   ├── portfolio_page.dart                # 포트폴리오 5-탭 컨테이너
│   ├── portfolio/
│   │   ├── widgets/                       # 7개 공용 위젯 (보유/매입/출금 다이얼로그, 차트)
│   │   └── tabs/                          # 5개 탭 + calculator
│   │       ├── widgets/                   # 4개 탭 전용 위젯 (target_allocation 관련)
│   │       └── dialogs/                   # 4개 탭 전용 다이얼로그
│   │
│   ├── stocks_page.dart                   # 주식 탭 (paywall gate)
│   ├── statistics_page.dart               # 통계 페이지
│   └── settings_page.dart                 # 설정 (Currency/Theme/Sync 등)
│
├── providers/                             # ChangeNotifier 9개
│   ├── portfolio_provider.dart            # 포트폴리오 핵심 상태 (544줄)
│   ├── account_provider.dart              # 가계부 항목 + 카테고리 + 수입
│   ├── settings_provider.dart             # 사용자 설정 (테마/언어/통화/구독)
│   ├── purchase_provider.dart, stock_provider.dart, navigation_provider.dart 등
│   └── portfolio_recompute.dart           # 순수 함수 — 보유/요약 재계산 로직
│
├── services/
│   ├── isar_service.dart                  # Isar ORM CRUD 싱글턴
│   ├── sync_service.dart                  # Supabase 업로드/다운로드
│   ├── sync_helpers.dart                  # JSON sanitize, hash 계산 (mirror tests 가능)
│   ├── stock_alert_service.dart           # Workmanager 백그라운드 알림
│   ├── yahoo_finance_service.dart         # 주식 가격 + 환율 API
│   ├── coin_gecko_service.dart            # 암호화폐 가격 API
│   ├── interstitial_ad_service.dart, app_open_ad_manager.dart  # AdMob
│   │
│   └── portfolio/                         # 포트폴리오 도메인 서비스 (Step 1-4 분리)
│       ├── withdrawal_service.dart        # 출금/투자이득 보유
│       ├── lot_service.dart               # 매입/매도 손실 인식
│       ├── price_service.dart             # 현재가 캐시 + 환율
│       ├── dividend_service.dart          # 배당금
│       └── loan_calculation_service.dart  # 대출 상환 일정
│
├── models/                                # 데이터 모델
│   ├── isar_models.dart                   # ORM 엔티티
│   ├── isar_models.g.dart                 # build_runner 생성 코드 (수정 금지)
│   ├── portfolio_models.dart              # UI 뷰모델 (HoldingViewModel, AccountSummary 등)
│   ├── account_models.dart                # 가계부 모델 (CategoryConfig 등)
│   ├── stock_models.dart                  # 주식 모델
│   └── column_config.dart                 # 동적 컬럼 표시 설정
│
├── widgets/                               # 글로벌 재사용 위젯 (11개)
│   ├── calc_amount_field.dart             # 계산기 입력 필드
│   ├── column_settings_dialog.dart        # 컬럼 표시/숨김 다이얼로그 (top-level showXxxDialog 패턴)
│   ├── sync_unlock_gate.dart              # 동기화 paywall gate
│   ├── stocks_unlock_gate.dart            # 주식 탭 paywall gate
│   ├── sync_conflict_dialog.dart          # 동기화 충돌 해결
│   └── … (차트, 포맷터, 로딩뷰, 광고 배너 등)
│
├── utils/                                 # 포맷팅/내보내기 유틸 (3개)
│   ├── amount_formatter.dart, money_display.dart  # 금액 포맷
│   └── widget_to_png_exporter.dart        # 위젯 → PNG 내보내기 (Share/저장 분기)
│
├── constants/                             # 상수 (app_constants.dart)
├── config/                                # 환경 설정 + 광고 ID
├── debug/                                 # 디버그 도구 (Isar inspector, network logger 등)
└── l10n/                                  # 한국어/영어 번역 (.arb + 생성 코드)

test/
├── providers/                             # Provider 단위 테스트 (정렬/필터/계산 로직)
├── services/
│   ├── sync_helpers_test.dart, onboarding_sample_seed_test.dart
│   └── portfolio/                         # 분리된 도메인 서비스 테스트
│       ├── dividend_service_test.dart
│       ├── lot_service_test.dart
│       └── loan_calculation_service_test.dart
├── widgets/                               # 위젯 테스트 (sync_unlock_gate, dashboard_section 등)
├── utils/widget_to_png_exporter_test.dart
├── env_config_develop_mode_test.dart
└── coverage_helper_test.dart              # lcov SF 항목 확장용 (lib/ 전체 import)

docs/
├── CODEBASE_MAP.md                        # 이 문서
└── YYYY-MM-DD_<feature-name>/             # 각 PR의 PRD.md + TRD.md 아카이브
```

---

## 3. Domain Map

### 3.1 가계부 (account_book)

| 책임 | 파일 |
|---|---|
| 페이지 진입점 | `pages/account_book_page.dart` |
| Sort/collapse state owner | `_AccountBookPageState` (페이지 안) |
| 카테고리 섹션 렌더 | `pages/account_book/widgets/category_section.dart` (CategorySection — DataTable + 정렬 칩) |
| 헤더 위젯 | `pages/account_book/widgets/income_header.dart`, `summary_card.dart`, `month_selector.dart`, `add_category_button.dart` |
| 다이얼로그 13개 | `pages/account_book/dialogs/` — 거래 추가/편집(AddEntryDialog/EditEntryDialog), 수입(AddIncomeDialog/IncomeEditDialog/IncomeManagerDialog), 카테고리(CategoryEditDialog/CategoryManagerDialog/CategoryResetDialog), 반복 템플릿(AddTemplateDialog/EditTemplateDialog/RecurringManagerDialog), 기타(RatioEditDialog/ResetMonthDialog) |

**의존 Provider**: `AccountProvider` (항목/카테고리/수입 통합), `SettingsProvider`.

### 3.2 포트폴리오 (portfolio)

| 책임 | 파일 |
|---|---|
| 페이지 진입점 (탭 컨테이너) | `pages/portfolio_page.dart` |
| 5개 탭 | `pages/portfolio/tabs/` — `dashboard_tab.dart`, `account_detail_tab.dart`, `history_tab.dart`, `loan_tab.dart`, `target_allocation_tab.dart` (+ `target_allocation_calculator.dart` 순수 계산) |
| 목표 배분 표 | `pages/portfolio/tabs/widgets/target_allocation_table.dart` (AllocationTable + _AllocationTableState) |
| 표 행 빌더 | `pages/portfolio/tabs/widgets/allocation_table_row_builder.dart` (AllocationTableRowBuilder — 7개 final + 8개 메서드) |
| 헤더 / 캡처뷰 | `pages/portfolio/tabs/widgets/target_allocation_header_card.dart`, `target_allocation_capture_view.dart` |
| 합계 다이얼로그 | `pages/portfolio/tabs/dialogs/target_allocation_totals_dialog.dart` (StatefulWidget — Share/저장 분기) |
| 카테고리 관리 다이얼로그 | `pages/portfolio/tabs/dialogs/allocation_category_dialogs.dart` (top-level showXxxDialog 함수 3개) |
| 컬럼 설정 다이얼로그 | `pages/portfolio/tabs/dialogs/allocation_column_settings_dialog.dart` |
| 표 셀 다이얼로그 7개 | `pages/portfolio/tabs/dialogs/allocation_table_dialogs.dart` (top-level 함수 7개 — 비율/계좌비중/보정/최소/카테고리 picker 등) |
| 공용 위젯 | `pages/portfolio/widgets/` — HoldingDialog, LotDialog, WithdrawalDialog, ReturnRateDialog, 차트 위젯 |

**의존 Provider**: `PortfolioProvider`, `AccountProvider`(가계부 수입과 연동), `SettingsProvider`.

**의존 Service**: `services/portfolio/{withdrawal,lot,price,dividend,loan_calculation}_service.dart` — Provider가 IsarService와 직접 통신하지 않고 Service에 위임. notifyListeners()/SyncService 호출은 Provider 책임.

### 3.3 주식 / 통계 / 설정

| 페이지 | 핵심 |
|---|---|
| `pages/stocks_page.dart` | 주식 탭 — `widgets/stocks_unlock_gate.dart`로 paywall, `services/yahoo_finance_service.dart`로 가격 조회, `services/stock_alert_service.dart`로 백그라운드 알림 |
| `pages/statistics_page.dart` | 통계 페이지 (StatisticsPage + StatisticsPageState public) |
| `pages/settings_page.dart` | 설정 — Currency/Alert Threshold 두 RadioGroup, 데이터 import/export 비동기 흐름, `widgets/sync_unlock_gate.dart`로 Sync paywall |

---

## 4. Naming & Pattern Conventions

### 4.1 다이얼로그 추출 패턴 (어느 쪽을 쓸지)

| 원본 패턴 | 추출 결과 | 예시 |
|---|---|---|
| Stateless `showDialog<T>(context: ..., builder: ...)` (Provider/Consumer 갱신) | **Top-level 함수**: `Future<T> showXxxDialog(BuildContext, ...)` | `widgets/column_settings_dialog.dart`, `tabs/dialogs/allocation_table_dialogs.dart`, `tabs/dialogs/allocation_category_dialogs.dart` |
| `StatefulBuilder` + `parentSetState` 콜백 안티패턴 | **`StatefulWidget` + `onChanged: VoidCallback?` prop** | `account_book/dialogs/*` 13개 |

### 4.2 widgets/ vs dialogs/ 분리

- `<domain>/widgets/`: AppBar/헤더/카드/표 셀 등 **build helper StatelessWidget/StatefulWidget**.
- `<domain>/dialogs/`: **AlertDialog/SimpleDialog 본문**을 갖는 클래스 또는 top-level showXxxDialog 함수.

### 4.3 Service 분리 (서비스 계층 책임 경계)

- `services/<verb>_service.dart` 또는 `services/<domain>/<noun>_service.dart`.
- Service는 **IsarService(또는 외부 API)만 의존**. ChangeNotifier 호출 ❌, SyncService 호출 ❌ — 두 책임은 Provider가.
- 신규 비즈니스 로직 추가 시 Provider에서 직접 IsarService 만지지 말고 Service로 위임.

### 4.4 Builder 클래스 패턴

상호 호출이 잦고 공통 의존성이 많은 build helper 묶음은 **Builder 클래스**로:
```dart
class AllocationTableRowBuilder {
  AllocationTableRowBuilder({required this.l10n, required this.fmt, ...});
  // 7 final 필드. 8 메서드. State.build()에서 인스턴스화 후 buildRows() 호출.
}
```
참고: `pages/portfolio/tabs/widgets/allocation_table_row_builder.dart`.

### 4.5 라이브러리 docstring

추출된 widget/dialog 파일 첫 줄에 `///` 한 줄 dartdoc + `library;` 디렉티브 (Dart 분석기 권장).

---

## 5. "어디에 추가할까?" 의사결정 가이드

| 추가하려는 것 | 위치 |
|---|---|
| 가계부 다이얼로그 | `lib/pages/account_book/dialogs/<name>_dialog.dart` (StatefulWidget + onChanged) |
| 가계부 헤더/카드 위젯 | `lib/pages/account_book/widgets/<name>.dart` (StatelessWidget) |
| 포트폴리오 탭 추가 | `lib/pages/portfolio/tabs/<name>_tab.dart` (+ `portfolio_page.dart`에 탭 등록) |
| 목표 배분 표 셀 다이얼로그 | `lib/pages/portfolio/tabs/dialogs/allocation_table_dialogs.dart`에 top-level 함수 추가 |
| 포트폴리오 도메인 비즈니스 로직 | `lib/services/portfolio/<noun>_service.dart` 신규 또는 기존 서비스에 추가. Provider는 위임만 |
| 외부 API 클라이언트 | `lib/services/<provider>_service.dart` (예: yahoo_finance, coin_gecko) |
| 새 ORM 엔티티 | `lib/models/isar_models.dart`에 클래스 추가 + `dart run build_runner build` |
| UI 뷰모델 | `lib/models/portfolio_models.dart` 또는 `account_models.dart` (도메인에 맞게) |
| 글로벌 재사용 위젯 | `lib/widgets/<name>.dart` |
| 포맷터/유틸 | `lib/utils/<name>.dart` |
| Provider 신규 | `lib/providers/<name>_provider.dart` (+ `main.dart`의 MultiProvider에 등록) |
| 다국어 문구 | `lib/l10n/app_ko.arb` + `app_en.arb` 양쪽 추가 |
| 신규 페이지 | `lib/pages/<name>_page.dart` |
| Workmanager 백그라운드 작업 | 기존 `services/stock_alert_service.dart` 패턴 참조 |

---

## 6. 핵심 Class ↔ File Lookup

| Class / Function | File | Notes |
|---|---|---|
| `TargetAllocationTab` | `pages/portfolio/tabs/target_allocation_tab.dart` | 페이지 진입 위젯 (281줄) |
| `AllocationTable` | `pages/portfolio/tabs/widgets/target_allocation_table.dart` | 표 위젯 + `_AllocationTableState` |
| `AllocationTableRowBuilder` | `pages/portfolio/tabs/widgets/allocation_table_row_builder.dart` | 행 빌더 클래스 (~447줄) |
| `TargetAllocationHeaderCard` | `pages/portfolio/tabs/widgets/target_allocation_header_card.dart` | 헤더 카드 |
| `TargetAllocationCaptureView` | `pages/portfolio/tabs/widgets/target_allocation_capture_view.dart` | PNG 캡처용 비-인터랙티브 표 |
| `TargetAllocationTotalsDialog` | `pages/portfolio/tabs/dialogs/target_allocation_totals_dialog.dart` | 합계 다이얼로그 (Share/저장) |
| `showAllocationTableCategoryRatioDialog` 등 7개 | `pages/portfolio/tabs/dialogs/allocation_table_dialogs.dart` | 표 셀 탭 다이얼로그 |
| `showManageAllocationCategoriesDialog` 등 3개 | `pages/portfolio/tabs/dialogs/allocation_category_dialogs.dart` | 카테고리 관리 |
| `showAllocationColumnSettingsDialog` | `pages/portfolio/tabs/dialogs/allocation_column_settings_dialog.dart` | 컬럼 설정 |
| `CategorySection` | `pages/account_book/widgets/category_section.dart` | 가계부 DataTable 카테고리 섹션 + 정렬 칩 |
| `SummaryCard`, `MonthSelector`, `AddCategoryButton`, `IncomeHeader` | `pages/account_book/widgets/` | 가계부 헤더/카드 |
| `AddEntryDialog`, `EditEntryDialog`, `IncomeManagerDialog` 등 13개 | `pages/account_book/dialogs/` | 가계부 다이얼로그 |
| `PortfolioProvider` | `providers/portfolio_provider.dart` | 메인 ChangeNotifier (544줄) |
| `AccountProvider` | `providers/account_provider.dart` | 가계부 통합 상태 |
| `WithdrawalService`, `LotService`, `PriceService`, `DividendService`, `LoanCalculationService` | `services/portfolio/` | Step 1-4에서 분리됨 |
| `IsarService` | `services/isar_service.dart` | DB 싱글턴 |
| `SyncService` | `services/sync_service.dart` | Supabase 동기화 |
| `sanitizeForJson`, `computeDataHash` | `services/sync_helpers.dart` | 동기화 헬퍼 (pure functions) |
| `HoldingViewModel`, `AccountSummary`, `PortfolioSummary`, `AllocationCategoryViewModel` | `models/portfolio_models.dart` | UI 뷰모델 |
| `CategoryConfig`, `EntryModel`, `IncomeEntry` 등 | `models/account_models.dart` | 가계부 모델 |
| `formatMoneyWith`, `amountFormatter` | `utils/money_display.dart`, `utils/amount_formatter.dart` | 금액 포맷 |
| `WidgetToPngExporter.shareAsPng` | `utils/widget_to_png_exporter.dart` | 위젯 PNG 내보내기 |
| `SyncUnlockGate`, `StocksUnlockGate` | `widgets/` | 페이월 게이트 |

---

## 7. 분해 히스토리 메모

각 PR의 PRD/TRD는 `docs/<YYYY-MM-DD>_<feature>/`에 아카이브.

| 작업 | PR | 결과 |
|---|---|---|
| Quick Win 위생 | #27 | print → debugPrint, README 보강 |
| Test safety net | #28 | CI gate, lcov coverage helper, sync_helpers 단위 테스트 |
| portfolio_provider Step 1-4 | #29-#32 | `services/portfolio/` 5개 서비스 분리 (1,074 → 544줄) |
| account_book_page Step 1-2 | #33-#34 | SummaryCard/MonthSelector/AddCategoryButton/IncomeHeader 추출 |
| account_book_page Step 3a/3b/3c | #35-#37 | 13개 다이얼로그 → `account_book/dialogs/` 일괄 추출 |
| account_book_page Step 4 | #43 | CategorySection (lifting state up + 콜백) |
| target_allocation_tab Step 1-5 | #38-#42 | 9개 클래스 → `tabs/widgets/` + `tabs/dialogs/` 분산 (2,434 → 281줄) |
| Lint/deprecated 정리 | #44 | 64 issue → 0 issue (withOpacity/Share/Radio 등) |

깊은 컨텍스트가 필요할 때만 `docs/<날짜>_<feature>/` 안의 PRD/TRD 참조. 일반 navigation에는 본 문서 §2-§6으로 충분.

---

## 8. 변경 시 주의사항

- **build_runner 생성물** (`*.g.dart`): 직접 수정 금지. 모델 변경 시 `dart run build_runner build` 재생성.
- **CI 검증**: `flutter analyze --no-fatal-infos` 0 errors / 0 warnings + `flutter test` 통과가 PR 머지 조건.
- **Surgical change 원칙** (CLAUDE.md §3): 한 PR에서 한 책임만. 무관한 lint/스타일 동시 정리 금지(별도 PR).
- **Dialog 추출 시 본문 character-for-character 동일성**: 분해 PR들은 모두 본문을 글자 단위 동일하게 유지하면서 클래스/함수 추출만 수행. 신규 추출 PR도 동일 원칙.
