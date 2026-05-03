# Non-Functional Compliance — Simple Home Workout Timer v1.0

- **Date**: 2026-05-03
- **Phase**: 6 (Non-functional verification)
- **Workflow**: ccc8382b-8f32-4f88-a522-40d197cd7835

---

## 1. 자동 검증 (CI)

`flutter test` 실행 시 아래 검사가 모두 자동으로 수행됩니다.

| 검사 항목 | 명령 / 파일 | 통과 조건 |
|---|---|---|
| 정적 분석 | `flutter analyze --no-fatal-infos` | 0 errors, 0 warnings |
| 전체 단위·위젯 테스트 | `flutter test` | 모든 테스트 GREEN |
| 네트워크 의존성 가드 | `test/policy/network_dependency_guard_test.dart` | `violations.isEmpty` |
| v1.0 제외 범위 스코프 가드 | `test/policy/scope_guard_test.dart` | `violations.isEmpty` |

> CI 파이프라인 yaml(.github/workflows/)은 별도 PR에서 추가 예정.
> 현재는 PR 전·후 로컬에서 `flutter test`를 수동 실행하여 확인한다.

---

## 2. 백그라운드 동작

### 구현

`lib/pages/timer_run_page.dart`의 `_TimerRunPageState`가
`WidgetsBindingObserver` mixin을 채택하여 앱 라이프사이클 변화를 직접 수신합니다.

| 라이프사이클 상태 | 동작 | 대상 |
|---|---|---|
| `AppLifecycleState.paused` | `_animController.stop()` | AnimationController (vsync ticker) |
| `AppLifecycleState.resumed` | `_animController.repeat()` — **단, 엔진이 `TimerState.running`일 때만** | AnimationController |
| 그 외 (`inactive`, `detached`) | 아무 동작 없음 | — |

- **TimerEngine** 자체는 절대 시각(absolute-clock) 기반이므로 백그라운드 진입/복귀 시 보정이 불필요합니다.
- **ForegroundService**는 `TimerOsBridgeProvider`가 별도로 관리합니다.

### 관련 테스트

- `test/pages/timer_run_page_test.dart` — T5.1~T5.6: 엔진 상태 전환 검증

> 라이프사이클 위젯 테스트(T3.1~T3.3)는 현재 헤드리스 환경에서
> ForegroundService / TTS 플랫폼 채널 충돌로 인해 intractable 판정.
> 수동 검증 절차는 §3 패킷 캡처 시 동시 수행.

---

## 3. 네트워크 0건 정책

### 자동 가드

`test/policy/network_dependency_guard_test.dart` — 차단 패키지 목록:

| 패키지 | 비고 |
|---|---|
| `http` | Dart 공식 HTTP 클라이언트 |
| `dio` | 인기 HTTP 클라이언트 |
| `chopper` | HTTP 코드 생성 라이브러리 |
| `retrofit` | HTTP 코드 생성 라이브러리 |
| `graphql` | GraphQL 클라이언트 |
| `graphql_flutter` | GraphQL Flutter 바인딩 |
| `websocket` | WebSocket 클라이언트 |
| `web_socket_channel` | WebSocket 채널 |
| `supabase_flutter` | Supabase BaaS |
| `firebase_core` | Firebase SDK 기반 |

위 패키지 중 하나라도 `pubspec.yaml`에 추가되면 `flutter test`가 즉시 실패합니다.

### 수동 패킷 캡처 절차

> 목적: 실제 기기에서 앱 실행 중 아웃바운드 네트워크 요청이 없는지 확인.

**Proxyman (macOS + iOS 시뮬레이터 / 실기기):**

```
1. Proxyman 설치 및 실행
2. iOS 실기기: 설정 → Wi-Fi → HTTP 프록시 → Proxyman IP:8888 입력
3. Proxyman에서 SSL 인증서 설치 (Certificate Trust)
4. 앱 실행 → 30분 루틴 시작
5. Proxyman "Filter" 탭에서 앱 번들 ID(com.example.fitnessTimer) 필터 적용
6. 결과: 아무 요청도 캡처되지 않아야 함
```

**mitmproxy (크로스 플랫폼):**

```bash
# 프록시 시작
mitmproxy --listen-port 8888

# Android 에뮬레이터
adb shell settings put global http_proxy <PC_IP>:8888

# 앱 실행 후 30분 루틴 시작
# mitmproxy 창에서 트래픽 0건 확인
# 완료 후 프록시 해제
adb shell settings put global http_proxy :0
```

**기대 결과:** 앱의 아웃바운드 TCP/TLS 연결 0건.

---

## 4. 배터리 30분 측정 절차

### Android (adb)

```bash
# 1. 측정 전 통계 초기화
adb shell dumpsys batterystats --reset

# 2. 앱 실행, 30분 루틴 시작
#    (5분 경과 후 홈 버튼 → 백그라운드 진입, 10분 경과 후 복귀 — 선택 사항)

# 3. 완료 후 통계 저장
adb shell dumpsys batterystats > battery_after.txt

# 4. 결과 분석
#    battery_after.txt 내 "Estimated power use" 섹션 확인
#    앱 패키지(com.example.fitnessTimer) 항목의 mAh 값 기록
```

**측정 양식:**

| 항목 | 값 |
|---|---|
| 기기 모델 | _(예: Samsung Galaxy S24)_ |
| Android 버전 | _(예: 14)_ |
| 배터리 용량 | _(예: 4000 mAh)_ |
| 측정 일시 | _(예: 2026-05-10 14:00)_ |
| 포그라운드 30분 소비량 | _____ mAh |
| 백그라운드 구간 소비량 | _____ mAh |
| 합산 소비 비율 | _____% |
| 합격 기준 | 30분 소비 ≤ 배터리 용량의 5% |
| 결과 | PASS / FAIL |

### iOS (Xcode Energy Log)

```
1. Xcode → Product → Profile → Energy Log 프로파일 선택
2. 기기 연결 후 앱 실행
3. 30분 루틴 수행 (백그라운드 구간 포함)
4. Instruments 종료 후 Energy Impact 컬럼 확인
5. Average Energy Impact < 20 을 목표로 함
```

---

## 5. v1.0 제외 범위 — placeholder 금지 항목

v1.0 범위 외 기능이 소스 트리에 침범하지 않도록 `test/policy/scope_guard_test.dart`가
`lib/` 디렉토리 전체를 스캔합니다.

### 차단 키워드 목록

| 키워드 / 패턴 | 매칭 방식 | 차단 이유 |
|---|---|---|
| `package:firebase_` | 접두사 | Firebase SDK 임포트 |
| `package:cloud_` | 접두사 | Cloud Firestore 등 임포트 |
| `package:supabase_` | 접두사 | Supabase SDK 임포트 |
| `WatchKit` | 정확 일치 | Apple Watch 연동 |
| `apple_watch` | 정확 일치 | Apple Watch 식별자 |
| `watch_kit` | 정확 일치 | WatchKit 식별자 |
| `garmin` | 부분 문자열 | Garmin 웨어러블 |
| `healthkit` | 부분 문자열 (대소문자 무시) | Apple HealthKit |
| `google_fit` | 정확 일치 | Google Fit |
| `package:fl_chart` | 접두사 | 차트 라이브러리 |
| `package:charts_` | 접두사 | 차트 라이브러리 |
| `\b[Aa]nalytics\b` | 단어 경계 | Analytics 클래스/식별자 |
| `\bSync\b` | 단어 경계 | Sync 클래스 (async/synchronize 는 제외) |
| `\bFirestore\b` | 단어 경계 | Firestore 식별자 |
| `\bFirebase\b` | 단어 경계 | Firebase 식별자 |
| `\bSupabase\b` | 단어 경계 | Supabase 식별자 |

위 패턴 중 하나라도 `lib/`의 `.dart` 파일에서 감지되면 `flutter test`가 즉시 실패합니다.

### 참조 테스트

`test/policy/scope_guard_test.dart` — `flutter test test/policy/scope_guard_test.dart` 로 단독 실행 가능.
