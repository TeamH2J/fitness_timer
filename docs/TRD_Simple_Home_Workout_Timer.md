# 📄 TRD: 심플 홈트 타이머 (가칭) 기술 요구사항 문서

본 문서는 기획(PRD) 단계에서 정의된 '심플 홈트 타이머'의 핵심 가치를 기술적으로 구현하기 위한 요구사항을 명시합니다.

---

## 1. 시스템 아키텍처 및 기술 스택 (System Architecture & Tech Stack)

본 프로젝트는 네트워크 의존성 없는 100% 로컬 기반 모바일 애플리케이션으로 설계됩니다.

* **플랫폼**: iOS 16.0 이상, Android 8.0 (API Level 26) 이상
* **추천 프레임워크**: **Flutter** (하나의 코드베이스로 iOS/Android 대응 및 커스텀 UI/애니메이션 구현에 유리) 또는 **Native (Swift/Kotlin)**
* **로컬 데이터베이스**: SQLite (Sqflite) 또는 Realm / Hive (가벼운 로컬 데이터 저장용)
* **상태 관리**: Provider, Riverpod 또는 BLoC (타이머의 초 단위 상태 변화를 UI에 지연 없이 반영하기 위해 선택)

---

## 2. 핵심 모듈 상세 설계 (Core Module Specifications)

### 2.1. 타이머 엔진 모듈 (Timer Engine)
* **상태 머신 (State Machine)**: `Idle(대기)` ➡️ `Running(실행 중)` ➡️ `Paused(일시정지)` ➡️ `Completed(완료)` 상태를 관리합니다.
* **흐름 제어**: `Countdown(준비)` ➡️ `Work(운동)` ➡️ `Rest(휴식)` 루프 반복 ➡️ `Cooldown(마무리)`.
* **시간 측정 방식**: 백그라운드 전환 시 발생하는 시간 오차(Drift)를 방지하기 위해 시스템의 **절대 시간(System Clock)** 기준으로 목표 시간과 현재 시간의 차이를 계산합니다.
* **횟수 모드(Reps Mode) 처리**: 내부 타이머는 설정된 '시간(Duration)' 기준으로 흐르되, UI 레이어에 '목표 횟수(Target Reps)' 메타데이터를 전달하여 화면에 노출합니다.

### 2.2. 오디오 및 피드백 제어 모듈 (Audio & Haptic Manager)
* **오디오 더킹 (Audio Ducking)**: 
    * **iOS**: `AVAudioSession`의 `duckOthers` 옵션 활성화.
    * **Android**: `AudioManager.requestAudioFocus` 호출 시 `AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK` 플래그 사용.
* **TTS (Text-to-Speech)**: Native OS 내장 엔진을 사용하며, 지연 시간(Latency) 최소화를 위해 앱 구동 시 엔진을 미리 초기화(Pre-warm)합니다.
* **진동 및 비프음**: iOS의 `CoreHaptics`와 Android의 `VibrationEffect`를 사용하여 상황별(운동 시작, 종료 3초 전 등) 피드백을 제공합니다.

### 2.3. 백그라운드 및 OS 연동 (OS Integration)
* **화면 켜짐 유지 (Wakelock)**: 타이머 실행 중에는 화면이 꺼지지 않도록 처리합니다.
* **잠금 화면 및 알림 지원**:
    * **iOS**: Live Activities (ActivityKit) 및 Dynamic Island를 통해 실시간 남은 시간을 표시합니다.
    * **Android**: Foreground Service와 Ongoing Notification을 통해 백그라운드 작동을 보장합니다.

---

## 3. 데이터베이스 스키마 설계 (Local DB Schema)

### Table: `Routine` (루틴 메타데이터)
| 필드명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `id` | UUID (PK) | 루틴 고유 아이디 |
| `title` | String | 루틴 이름 (예: 아침 전신 15분) |
| `prep_time` | Int | 준비 시간(초) |
| `cooldown_time` | Int | 마무리 시간(초) |
| `total_cycles` | Int | 총 반복 횟수 |

### Table: `Exercise_Item` (루틴 내 개별 항목)
| 필드명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `id` | UUID (PK) | 항목 고유 아이디 |
| `routine_id` | UUID (FK) | 소속 루틴 아이디 |
| `order_index` | Int | 실행 순서 |
| `type` | Enum | WORK_TIME, WORK_REPS, REST |
| `duration` | Int | 진행 시간(초) |
| `target_reps` | Int | 목표 횟수 (Nullable) |
| `name` | String | 운동명 (TTS용) |

### Table: `History` (완료 기록)
| 필드명 | 타입 | 설명 |
| :--- | :--- | :--- |
| `id` | UUID (PK) | 기록 고유 아이디 |
| `routine_id` | UUID (FK) | 완료된 루틴 아이디 |
| `completed_at` | Timestamp | 루틴 완료 일시 |

---

## 4. UI/UX 구현 기술 가이드 (UI/UX Tech Specs)

* **시인성 최적화**: 
    * 다크 모드를 기본으로 적용하며, 고대비 색상(High Contrast)을 사용하여 가독성을 높입니다.
    * 숫자 폰트는 시스템 설정을 따르지 않고 고정된 대형 크기로 렌더링합니다.
* **전체 화면 터치 제어**:
    * 투명한 Overlay GestureDetector를 최상단에 배치하여 화면 어디를 눌러도 `togglePlayPause()`가 호출되도록 합니다.
* **진행률 렌더링 (Progress Indicator)**:
    * 60fps의 부드러운 애니메이션을 위해 Canvas API(`CustomPaint` 등)를 사용하여 원형 프로그레스 바를 렌더링합니다.

---

## 5. 비기능 요구사항 및 제약 사항

* **배터리 효율**: 앱이 백그라운드로 전환되면 UI 렌더링 로직을 중단하고 알림창 업데이트 주기를 최적화합니다.
* **오프라인 보장**: 서버 통신 및 로그인을 배제하여 즉각적인 사용성을 보장합니다.
* **제외 범위 (v1.0)**: 클라우드 동기화, 세트 건너뛰기, 스마트워치 연동, 상세 통계 분석 기능.
