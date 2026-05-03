# E2E 테스트 시나리오 — fitnessTimer v1.0

실기기(iOS / Android) 수동 검증 절차. `flutter test`의 단위·통합 테스트를 통과한 이후, 머지 전 기기에서 직접 실행하여 검증한다.

**실행 환경**:
- iOS: iPhone (iOS 16.0+), 다크 모드 OS 설정
- Android: Android 기기 (API 26+), 다크 모드 OS 설정
- 빌드: `flutter run --release` (또는 `flutter run`)

---

### S1 — 홈 / 신규 루틴 생성

**사전 준비**: 앱 첫 실행 (DB 비어있음). 또는 기기에서 앱 데이터를 초기화한 후 재시작.

**단계**:
1. 홈 화면 진입 → 빈 상태 메시지("루틴 없음" 또는 안내 텍스트) 표시 확인.
2. 우하단 FAB(+) 탭 → 루틴 편집 화면 이동.
3. 제목 입력 (예: "아침 운동").
4. 준비 시간(prep) = 10초 설정.
5. "운동 추가" 버튼으로 항목 3개 추가:
   - 항목 1: 이름 "스쿼트", duration = 30초, type = WORK_TIME
   - 항목 2: 이름 "휴식", duration = 15초, type = REST
   - 항목 3: 이름 "팔굽혀펴기", duration = 20초, type = WORK_TIME
6. 저장(체크 아이콘) 탭.

**기대 결과**:
- 홈 리스트에 카드 1개 표시.
- 카드에 제목 "아침 운동" + "3 항목" + 대략적인 총 시간 표기.

**실패 시 디버깅**:
- DB 저장 실패 → `flutter logs`에서 sqflite 오류 확인.
- 화면 미갱신 → `refreshableRoutinesProvider.invalidate()` 호출 누락 여부 확인 (`home_provider.dart`).

---

### S2 — 타이머 전체 흐름 (prep → work → rest → cooldown → 완료)

**사전 준비**: S1에서 생성한 루틴 존재. 쿨다운 = 10초로 설정.

**단계**:
1. 홈에서 루틴 카드 탭 → 타이머 실행 화면(TimerRunPage) 이동.
2. 시작 버튼 탭 → prep 10초 카운트다운 시작. TTS "준비" 또는 카운트 음성 확인.
3. prep 종료 → 항목 1 "스쿼트" 30초 work 페이즈 시작. TTS "스쿼트" 음성 및 비프음 확인.
4. work 종료 → 항목 2 "휴식" 15초 rest 페이즈 자동 전환.
5. rest 종료 → 항목 3 "팔굽혀펴기" 20초 work 페이즈 자동 전환.
6. work 종료 → cooldown 10초 자동 전환.
7. cooldown 종료 → 완료 화면(CompletePage) 자동 이동.
8. 홈 → 히스토리 페이지 → 방금 완료한 기록 1건 표시 확인.

**기대 결과**:
- 모든 페이즈가 자동 순서대로 전환.
- 각 페이즈 시작 시 TTS 음성 + 비프음 재생.
- 완료 화면 진입 후 히스토리에 기록 자동 추가.

**실패 시 디버깅**:
- 페이즈 전환 안 됨 → `TimerEngine` 이벤트 stream 로그 확인.
- 히스토리 미기록 → `CompletePage`에서 `insertHistory()` 호출 누락 여부 확인.

---

### S3 — Pause / Resume

**사전 준비**: 루틴 실행 중 work 페이즈 진행 중 상태.

**단계**:
1. 타이머 실행 화면에서 work 페이즈 중 화면 탭(또는 일시정지 버튼) → 타이머 정지.
2. 잔여 시간(예: 20초) 화면에 고정됨 확인.
3. 5초 대기.
4. 다시 화면 탭(또는 재개 버튼) → 타이머 재개.

**기대 결과**:
- 재개 후 잔여 시간이 정지 시점(예: 20초)부터 차감 시작. 5초 drift 없음.
- pause 상태에서 진동/TTS 없음.

**실패 시 디버깅**:
- drift 발생 → `TimerEngine`의 `_pausedAt` / `_resumeOffset` 계산 로직(`timer_engine.dart`) 확인.
- 재개 후 이벤트 재구독 → `FeedbackController.attach()` 정상 호출 여부 확인.

---

### S4 — 백그라운드 5분 동작

**사전 준비**: 루틴 실행 중 work 페이즈 진행 중 상태. 잔여 시간 6분 이상인 루틴 사용.

**단계**:
1. 타이머 실행 중 홈 버튼(또는 앱 스위처로 앱 백그라운드 전환).
2. 5분 대기.
3. 앱으로 복귀.

**기대 결과 (Android)**:
- 상태바에 포그라운드 서비스 알림 표시 확인 (5분 동안 유지).
- 복귀 시 잔여 시간이 실제 경과 시간만큼 감소 (drift 0).

**기대 결과 (iOS)**:
- 복귀 시 타이머가 실제 경과 시간 반영. (iOS background 제한으로 포그라운드 서비스 없음.)

**실패 시 디버깅**:
- Android drift → `ForegroundServiceController` 및 `AppLifecycleObserver` 확인 (`services/os/`).
- 알림 미표시 → Android 알림 권한 설정 확인.

---

### S5 — 잠금화면 알림 (Android 우선)

**사전 준비**: Android 기기. 타이머 실행 중.

**단계**:
1. 전원 버튼으로 화면 잠금.
2. 잠금화면에서 알림 바 또는 알림 영역 확인.
3. 알림에 현재 운동 이름 + 잔여 시간 표시 확인.
4. 잠금 해제 후 앱 복귀 → TTS / 비프음 정상 재개 확인.

**기대 결과**:
- 잠금화면에 `NotificationThrottler`가 조절한 간격으로 알림 업데이트.
- 잠금 해제 후 오디오 세션 복원, 피드백 정상 동작.

**실패 시 디버깅**:
- 알림 없음 → `flutter_local_notifications` 설정 및 Android 알림 채널 확인.
- 잠금 해제 후 오디오 없음 → `AudioSessionConfigurator` 재설정 로직 확인.

---

### S6 — 오디오 덕킹

**사전 준비**: 음악 앱(Spotify, Apple Music 등)으로 음악 재생 중.

**단계**:
1. fitnessTimer에서 루틴 시작.
2. 첫 TTS 또는 비프음 발생 시점에 배경 음악 볼륨 감소 확인.
3. 루틴 완료 (또는 정지) → 배경 음악 볼륨 복원 확인.

**기대 결과**:
- 운동 중 음악 볼륨 자동 감소 (덕킹).
- 운동 종료 후 음악 볼륨 자동 복원.

**실패 시 디버깅**:
- 덕킹 안 됨 → `AudioSessionConfigurator`의 `AudioSessionCategory` 설정 확인 (`audio_session_configurator.dart`).
- iOS에서 복원 안 됨 → `setActive(false)` 호출 시점 확인.

---

### S7 — textScale 접근성

**사전 준비**: OS 설정 → 접근성 → 텍스트 크기를 최대 또는 큰 값으로 변경.

**단계**:
1. fitnessTimer 앱 실행.
2. 타이머 실행 화면의 큰 숫자(잔여시간) 크기 확인.
3. 루틴 편집 화면, 홈 화면의 텍스트 크기 확인.

**기대 결과**:
- 타이머 큰 숫자 (`FixedTextStyles`) → textScale 변화에도 크기 고정.
- 나머지 텍스트(제목, 버튼 레이블 등) → 시스템 텍스트 크기에 따라 적절히 확대.
- 레이아웃 overflow 없음.

**실패 시 디버깅**:
- 큰 숫자가 커짐 → `FixedTextStyles`에서 `textScaleFactor: 1.0` 또는 `MediaQuery.withNoTextScaling` 적용 여부 확인 (`fixed_text_styles.dart`).
- overflow → 해당 위젯의 `Flexible` / `Expanded` / `overflow` 처리 확인.

---

### S8 — 히스토리 5건 표시

**사전 준비**: 동일 루틴을 5회 완료한 상태.

**단계**:
1. 홈 화면 → 히스토리 탭 이동 (또는 상단 내비게이션으로 HistoryPage 접근).
2. 히스토리 목록 확인.

**기대 결과**:
- 5건의 기록이 최신순(가장 최근 완료가 상단)으로 표시.
- 각 항목에 루틴 이름 + 완료 시각 표기.

**실패 시 디버깅**:
- 건수 불일치 → `DatabaseService.getHistories()` 쿼리의 `ORDER BY completed_at DESC` 및 `LIMIT` 파라미터 확인.
- 루틴 이름 미표시 → `histories` 조인 또는 `routine_id`로 별도 조회 로직 확인.

---

### S9 — Reps 모드 (WORK_REPS 항목)

**사전 준비**: 루틴에 `WORK_REPS` 타입 항목 1개 추가 (이름: "버피", targetReps: 15, duration: 45초).

**단계**:
1. 루틴 편집에서 WORK_REPS 항목 추가 후 저장.
2. 루틴 시작 → WORK_REPS 페이즈 진입.
3. 타이머 실행 화면에서 "목표: 15회" (또는 유사한 reps 표기) 노출 확인.
4. 45초 경과 → 다음 페이즈 자동 전환 확인.

**기대 결과**:
- 화면에 targetReps 값 노출.
- duration이 끝나면 자동으로 다음 phase 전환 (사용자가 직접 넘기지 않아도 됨).

**실패 시 디버깅**:
- reps 미표시 → `TimerRunPage`에서 `snapshot.targetReps` 렌더링 확인.
- 자동 전환 안 됨 → `TimerEngine`의 phase queue 빌드 로직 확인 (`timer_engine.dart`).

---

### S10 — 루틴 삭제 cascade

**사전 준비**: 루틴 1개 + 해당 루틴의 히스토리 2건 이상 존재.

**단계**:
1. 홈 화면에서 해당 루틴 카드 길게 탭 (또는 삭제 버튼).
2. 삭제 확인 다이얼로그 → 확인 탭.
3. 홈 리스트에서 해당 카드 사라짐 확인.
4. 히스토리 페이지 → 해당 루틴의 기록이 함께 삭제됨 확인.

**기대 결과**:
- `routines` 테이블에서 해당 행 삭제.
- `exercise_items`, `histories` 테이블에서 `routine_id` 매칭 행 자동 삭제 (ON DELETE CASCADE).
- 홈 리스트 및 히스토리 페이지 즉시 갱신.

**실패 시 디버깅**:
- 히스토리 미삭제 → DB의 FK `ON DELETE CASCADE` 설정 확인 (`database_service.dart`의 `onCreate`).
- 화면 미갱신 → 삭제 후 `routinesRefreshProvider` 카운터 increment 및 `refreshableRoutinesProvider.invalidate()` 호출 확인.
