# PRD: buildTools를 fitness_timer에 맞게 변환

**Feature ID**: `adapt-buildtools`
**Workflow ID**: `3601f271-a581-490b-a34a-e99df2646e16`
**Version**: v1.0
**Date**: 2026-05-06

---

## 1. Overview

`buildTools/` 폴더는 다른 Flutter 프로젝트(`account_book`)에서 통째로 복사된 Windows용 배치 자동화 스크립트(`build_and_deploy.bat`, `build_release.bat`, `deploy_to_play.bat`, `secrets.prod.json`)이다. 현재 fitness_timer에서는 다음 이유로 정상 동작하지 않는다.

- 산출물 이름이 `account_book-v*.aab`로 하드코딩됨
- `--flavor prod` 옵션을 사용하지만 fitness_timer는 productFlavors가 정의되어 있지 않음
- `--dart-define-from-file=buildTools\secrets.prod.json` (Supabase 키)와 `ADS_ENABLED`/`PURCHASE_ENABLED`/`DEBUG_TOOLS_ENABLED` dart-define들이 fitness_timer 코드 어디에서도 읽히지 않음
- Windows 데스크톱 빌드 단계가 포함되어 있으나 fitness_timer는 모바일(Android) 전용으로 운영
- `deploy_to_play.bat`가 호출하는 `android/Gemfile`, `android/fastlane/Fastfile`이 존재하지 않음
- Android release 빌드가 debug 키로 서명되어 있어 Play Store 업로드 시 거부됨

본 작업은 위 스크립트들을 fitness_timer에 맞게 변환하고, Fastlane / release signing의 누락된 스캐폴딩을 함께 채워 `버전 자동 bump → AAB 빌드 → Play Store Internal Testing 업로드` 파이프라인이 한 번에 동작하도록 만든다.

## 2. Goals

- **G1**: `buildTools\build_release.bat`를 더블 클릭(또는 `build_and_deploy.bat` 메뉴)만으로 fitness_timer의 release AAB가 정상 생성되도록 한다.
- **G2**: `buildTools\deploy_to_play.bat`가 자동으로 Play Store Internal Testing 트랙에 AAB를 업로드하도록 Fastlane 설정을 갖춘다 (사용자는 service-account JSON과 keystore만 채우면 됨).
- **G3**: `pubspec.yaml`의 버전을 매 빌드마다 자동 bump하여 Play Store가 동일 versionCode 거부하는 일이 없도록 한다 (기존 동작 유지).
- **G4**: 사용자가 채워야 할 비밀(서명 keystore, service-account JSON)은 명확한 템플릿/예시 파일로 안내하고 실제 비밀은 절대 저장소에 커밋되지 않도록 `.gitignore`로 차단한다.

## 3. User Stories

- **US1** — 개발자(혼자 운영)로서, `buildTools\build_and_deploy.bat`을 실행해 메뉴 [1]을 고르면 별도 입력 없이 버전이 bump되고 release AAB가 만들어지고 Play Store Internal에 업로드까지 끝나기를 원한다.
- **US2** — 개발자로서, 빌드만 필요할 때 메뉴 [2]를 골라 AAB만 만들고 업로드는 건너뛸 수 있어야 한다.
- **US3** — 개발자로서, 자격 증명/keystore 없이 처음 스크립트를 실행했을 때 "어디에 어떤 파일을 두면 되는지"가 에러 메시지로 명확히 안내되어야 한다 (그냥 크래시는 안 됨).
- **US4** — 개발자로서, fitness_timer 저장소에 서명 keystore나 service-account JSON이 실수로 커밋되면 안 된다.

## 4. Functional Requirements

### FR1. `build_release.bat` 변환
- **FR1.1** — 산출물 이름의 모든 `account_book` 문자열을 `fitness_timer`로 교체. 최종 보관 사본 경로는 `build\app\outputs\bundle\release\fitness_timer-v{version}.aab`.
- **FR1.2** — `flutter build appbundle` 명령에서 `--flavor prod` 및 모든 `--dart-define=...`, `--dart-define-from-file=...` 옵션을 제거하여 단순히 `flutter build appbundle --release`로 단축.
- **FR1.3** — Windows 빌드 단계(`flutter build windows ...` + ZIP 압축 블록) 전체를 제거하고 진행 표시를 [1/3] ~ [3/3]으로 정리.
- **FR1.4** — 기존 버전 자동 bump 로직(`pubspec.yaml`의 `version: X.Y.Z+N`을 `X.Y.(Z+1)+(N+1)`로 갱신)은 그대로 유지.
- **FR1.5** — 빌드 산출물은 `app-release.aab`(원본, Fastlane이 참조)와 `fitness_timer-v{version}.aab`(보관 사본) 두 개가 모두 남아야 함.

### FR2. `deploy_to_play.bat` 변환
- **FR2.1** — 업로드 직전에 `android\fastlane\play-store-credentials.json`(service-account JSON) 존재 여부를 확인하고, 없으면 "place service-account JSON at android\\fastlane\\play-store-credentials.json" 같은 명확한 메시지를 출력하고 비0 종료 코드로 종료.
- **FR2.2** — `android\Gemfile` 존재 여부도 확인하고 없으면 명확한 안내 후 종료.
- **FR2.3** — Fastlane 호출 방식을 `bundle binstubs fastlane --force` + `ruby bin\fastlane upload_internal` → `bundle exec fastlane upload_internal`로 단순화.
- **FR2.4** — AAB 경로는 `build\app\outputs\bundle\release\app-release.aab`로 유지 (FR1.5에서 원본 보존됨).

### FR3. `build_and_deploy.bat` 변환
- 메뉴 구조와 동작 그대로 유지. (Windows 관련 텍스트는 원래 없으므로 변경 없음.)

### FR4. `secrets.prod.json` 처리
- **FR4.1** — 파일을 삭제. 더 이상 어떤 스크립트도 참조하지 않음.

### FR5. Android release signing 스캐폴딩
- **FR5.1** — `android/app/build.gradle.kts` 수정:
  - `import java.util.Properties` / `import java.io.FileInputStream` 추가
  - `key.properties` 파일을 로드 (없으면 빈 Properties로 fallback)
  - `signingConfigs { create("release") { ... } }` 블록 추가 — keyAlias/keyPassword/storeFile/storePassword를 properties에서 읽음
  - `buildTypes.release.signingConfig`을 `key.properties` 존재 시 release, 없으면 기존 debug로 fallback
- **FR5.2** — `android/key.properties.example` 신규 파일 (템플릿) 생성. 실제 `android/key.properties`는 사용자가 채움.

### FR6. Fastlane 스캐폴딩
- **FR6.1** — `android/Gemfile` 신규 생성: `source "https://rubygems.org"` + `gem "fastlane"`.
- **FR6.2** — `android/fastlane/Appfile` 신규 생성: `json_key_file("fastlane/play-store-credentials.json")` + `package_name("com.h2j.fitness_timer")`.
- **FR6.3** — `android/fastlane/Fastfile` 신규 생성: `:android` 플랫폼의 `upload_internal` lane을 정의. `upload_to_play_store(track: "internal", aab: "../build/app/outputs/bundle/release/app-release.aab", skip_upload_metadata/images/screenshots/changelogs: true)`.

### FR7. `.gitignore` 추가
- 다음 항목 추가:
  - `android/key.properties`
  - `*.jks`, `*.keystore`
  - `android/fastlane/report.xml`
  - `android/fastlane/Preview.html`
  - `android/fastlane/play-store-credentials.json`
  - `android/fastlane/README.md` (fastlane 자동 생성)
- `Gemfile.lock`은 의도적으로 커밋 대상으로 둠 (Ruby 앱 관례).

## 5. Non-Functional Requirements

- **NFR1 — 정적 분석**: 변경 후 `flutter analyze`(프로젝트 루트)에서 신규 에러/경고 0건. (build.gradle.kts는 Kotlin이므로 영향 없으나 안전 차원에서 확인.)
- **NFR2 — 안전 fallback**: `android/key.properties`가 없을 때도 `flutter build appbundle --release`가 debug 서명으로 통과해야 한다 (개발 중 빌드 깨짐 방지).
- **NFR3 — 보안**: keystore 파일(`*.jks`), `key.properties`, Play Console service-account JSON 어느 것도 실수로 커밋될 수 없도록 `.gitignore`로 보장.
- **NFR4 — 호환성**: 스크립트는 Windows + cmd.exe 환경 가정. PowerShell/Linux 호환은 비범위.
- **NFR5 — 자동화 도구 외 코드 무영향**: `lib/` 하위 Dart 코드, iOS 설정, pubspec.yaml의 의존성 목록은 변경하지 않는다. `pubspec.yaml`의 `version:` 라인만 build_release.bat 실행 시 자동 변경됨 (기존 동작).

## 6. Out of Scope

- iOS 빌드/배포 자동화 (현재 작업은 Android 전용).
- Windows 데스크톱 빌드 (의도적으로 제거).
- 실제 keystore 생성, service-account JSON 발급, Play Console 앱 등록.
- GitHub Actions / 원격 CI 구성. (로컬 Windows 머신 실행만 대상.)
- `lib/` 내 Dart 코드 수정, 새로운 dart-define 도입.
- buildTools 사용법 문서(README.md) 신규 생성. (CLAUDE.md §1 simplicity, 사용자 미요청.)
- `Gemfile.lock` 사전 생성 — 사용자가 첫 `bundle install` 시 자동 생성하여 후속 커밋.
- 기존 미서명/debug 서명 release AAB로 이미 빌드된 산출물 정리.

## 7. Revision History

| Version | Date | Changes |
|---|---|---|
| v1.0 | 2026-05-06 | Initial PRD. Plan-mode 협의 결과(Android 전용, Fastlane 스캐폴딩 포함, dart-define 전부 제거, key.properties 템플릿 포함) 반영. |
