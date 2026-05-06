# TRD: adapt-buildtools

- Date: 2026-05-06
- Author: TRD Agent
- Reference: PRD `.claude/outputs/PRD.md`

---

## 1. System Architecture Diagram

```
Developer (Windows)
       |
       v
buildTools\build_and_deploy.bat   <-- entry point (menu)
       |
       +--[menu 1/2]--> buildTools\build_release.bat
       |                      |
       |                      |  1. Read/bump pubspec.yaml version (PowerShell)
       |                      |  2. flutter pub get
       |                      |  3. flutter build appbundle --release
       |                      |        |
       |                      |        v
       |                      |  android/app/build.gradle.kts
       |                      |        |-- signingConfigs.release (key.properties present)
       |                      |        |-- signingConfigs.debug   (key.properties absent)
       |                      |        v
       |                      |  build\app\outputs\bundle\release\
       |                      |        app-release.aab            (Fastlane target)
       |                      |        fitness_timer-v{X.Y.Z}.aab (archive copy)
       |
       +--[menu 1/3]--> buildTools\deploy_to_play.bat
                              |
                              |  1. Guard: app-release.aab exists?
                              |  2. Guard: android\fastlane\play-store-credentials.json exists?
                              |  3. Guard: android\Gemfile exists?
                              |  4. cd android && bundle exec fastlane upload_internal
                              |        |
                              |        v
                              |  android/fastlane/Fastfile  (upload_internal lane)
                              |        Appfile: package_name, json_key_file
                              |        v
                              |  Google Play Console — Internal Testing Track

Secrets (gitignored — never in repo):
  android/key.properties
  android/*.jks / *.keystore
  android/fastlane/play-store-credentials.json
```

---

## 2. Tech Stack & Dependencies

| Item | Choice | Reason |
|------|--------|--------|
| Build script language | Windows cmd.exe batch (.bat) | Existing scripts; Windows-only scope per NFR4 |
| Flutter build command | `flutter build appbundle --release` | Removes unsupported `--flavor prod` and all `--dart-define` flags |
| Version bump | PowerShell one-liner inside .bat | Existing mechanism; reused unchanged |
| Android signing | `key.properties` + `build.gradle.kts` signingConfigs | Standard Flutter/Android pattern; graceful debug fallback per NFR2 |
| Ruby dependency manager | Bundler (`bundle exec`) | Locks Fastlane gem version via Gemfile |
| Play Store uploader | Fastlane `upload_to_play_store` action | Standard Fastlane action for Google Play |
| Play Store auth | Google service-account JSON | Fastlane supply plugin standard |
| New Dart/Flutter deps | None | NFR5: `lib/` and `pubspec.yaml` dependencies unchanged |

---

## 3. Module / Component Specification

### buildTools\build_release.bat (modified)

- Role: Version bump + Android-only AAB release build + artifact copy
- Responsibilities:
  - Read `version: X.Y.Z+N` from `pubspec.yaml`
  - Increment patch (`Z+1`) and build number (`N+1`) via PowerShell
  - Run `flutter pub get`
  - Run `flutter build appbundle --release` (no `--flavor`, no `--dart-define`, no `--dart-define-from-file`)
  - Delete old `fitness_timer-v*.aab` copies; copy `app-release.aab` to `fitness_timer-v{NEW_VERSION}.aab`
  - Print step progress [1/3], [2/3], [3/3] (Windows build step removed; was steps 3–4)
- Removes: `--flavor prod`, all `--dart-define=...`, `--dart-define-from-file=buildTools\secrets.prod.json`, the entire Windows build and ZIP artifact block, and `account_book` artifact name references
- Interface: Called directly or via `build_and_deploy.bat --no-pause`; exits 0 on success, 1 on error

### buildTools\deploy_to_play.bat (modified)

- Role: Play Store Internal Testing upload via Fastlane
- Responsibilities:
  - Verify `build\app\outputs\bundle\release\app-release.aab` exists; if not, print actionable error and exit /b 1
  - Verify `android\fastlane\play-store-credentials.json` exists; if not, print actionable error and exit /b 1
  - Verify `android\Gemfile` exists; if not, print actionable error and exit /b 1
  - Read and display current version from `pubspec.yaml`
  - `cd android && bundle exec fastlane upload_internal`
- Removes: `bundle binstubs fastlane --force` + `ruby bin\fastlane upload_internal` (replaced with `bundle exec fastlane upload_internal`)
- Interface: Called directly or via `build_and_deploy.bat --no-pause`; exits 0/1

### buildTools\build_and_deploy.bat (no change)

- Role: Entry-point menu combining build and deploy steps
- Responsibilities: Present menu [1]/[2]/[3], delegate to other two scripts
- Interface: Double-click or terminal; interactive stdin

### buildTools\secrets.prod.json (deleted)

- No script references it after FR1.2 and FR1.3 changes; delete the file.

### android\app\build.gradle.kts (modified)

- Role: Android build configuration with conditional release signing
- Responsibilities:
  - Add `import java.util.Properties` and `import java.io.FileInputStream` at top
  - Load `android/key.properties` into a `Properties` object; if file is absent, use empty `Properties` (no exception)
  - Define `signingConfigs { create("release") { ... } }` reading `storeFile`, `storePassword`, `keyAlias`, `keyPassword` from the loaded properties
  - In `buildTypes { release { ... } }`: if `key.properties` exists use `signingConfigs.getByName("release")`, else keep existing `signingConfigs.getByName("debug")`
- Interface: Consumed by Gradle during `flutter build appbundle`; no change to Dart/Flutter API

### android\key.properties.example (new file)

- Role: Committed template showing the required key.properties format
- Responsibilities: Document four required fields with placeholder values; developer copies file to `android/key.properties` and fills real values
- Interface: Reference file only; not read by any script or Gradle

### android\Gemfile (new file)

- Role: Ruby gem manifest for Fastlane
- Responsibilities: Declare `source "https://rubygems.org"` and `gem "fastlane"`
- Interface: Read by `bundle install`; generates `Gemfile.lock` on first run (Gemfile.lock is intentionally committed per FR7)

### android\fastlane\Appfile (new file)

- Role: Fastlane project-level configuration
- Responsibilities: Set `json_key_file("fastlane/play-store-credentials.json")` and `package_name("com.h2j.fitness_timer")`
- Interface: Auto-loaded by Fastlane before any lane runs

### android\fastlane\Fastfile (new file)

- Role: Fastlane lane definitions for Android
- Responsibilities: Define `platform :android` with `lane :upload_internal` that calls `upload_to_play_store` targeting the Internal Testing track; set `aab` path to `"../build/app/outputs/bundle/release/app-release.aab"`; set `skip_upload_metadata`, `skip_upload_images`, `skip_upload_screenshots`, `skip_upload_changelogs` to `true`
- Interface: Invoked via `bundle exec fastlane upload_internal` from `android/` directory

### .gitignore (modified)

- Role: Prevent secrets and generated Fastlane artifacts from entering the repo
- Responsibilities: Append entries for `android/key.properties`, `*.jks`, `*.keystore`, `android/fastlane/play-store-credentials.json`, `android/fastlane/report.xml`, `android/fastlane/Preview.html`, `android/fastlane/README.md`
- `Gemfile.lock` is intentionally not gitignored (Ruby app convention)

---

## 4. Data Model / Schema

This feature introduces no database schema changes. The two runtime data files involved are:

### android/key.properties (gitignored — template committed as key.properties.example)

| Field | Type | Constraint | Description |
|-------|------|------------|-------------|
| storePassword | String | Required for release signing | Password protecting the .jks keystore file |
| keyPassword | String | Required for release signing | Password for the specific key alias inside the keystore |
| keyAlias | String | Required for release signing | Alias name of the signing key entry |
| storeFile | String (path) | Required for release signing | Absolute or relative path to the .jks keystore file |

### pubspec.yaml version field (mutated by build_release.bat at runtime)

| Field | Format | Bump Rule |
|-------|--------|-----------|
| version | `MAJOR.MINOR.PATCH+BUILD` | Each `build_release.bat` run: PATCH += 1, BUILD += 1 |

Example: `1.0.2+3` becomes `1.0.3+4`.

---

## 5. API / Interface Specification

This feature has no HTTP APIs. All interfaces are command-line invocations.

### build_and_deploy.bat

- Invocation: `buildTools\build_and_deploy.bat` (from any directory — `cd /d` handles cwd)
- Stdin: User enters 1, 2, or 3; invalid input loops back with prompt
- Stdout: Menu, step headers, delegated output from sub-scripts
- Exit code: 0 = success, 1 = failure in sub-script

### build_release.bat

- Invocation: `buildTools\build_release.bat [--no-pause]`
- `--no-pause` flag: suppresses `pause` at end and on error (for scripted calls from build_and_deploy.bat)
- Exit code: 0 = success, 1 = any step failure

### deploy_to_play.bat

- Invocation: `buildTools\deploy_to_play.bat [--no-pause]`
- `--no-pause` flag: suppresses `pause` at end and on error
- Exit code: 0 = success, 1 = guard check failure or Fastlane error

### Fastlane lane: upload_internal

- Invocation: `bundle exec fastlane upload_internal` (from `android/` directory)
- Prerequisite files: `fastlane/play-store-credentials.json`, `fastlane/Appfile`, `fastlane/Fastfile`
- Input AAB: `../build/app/outputs/bundle/release/app-release.aab`
- Effect: Uploads AAB to Play Store Internal Testing track
- Exit code: 0 = success, non-zero = Fastlane/API error

---

## 6. Error Handling & Exception Flow

| Scenario | Handling | User Message |
|----------|----------|--------------|
| Flutter not in PATH | `build_release.bat` exits /b 1 immediately | `ERROR: Flutter not found in PATH. Please install Flutter and add flutter\bin to your system PATH.` |
| `flutter pub get` fails | exits /b 1 | `ERROR: Build failed. Check the output above.` |
| `flutter build appbundle` fails | exits /b 1 | `ERROR: Build failed. Check the output above.` |
| `app-release.aab` not found before deploy | `deploy_to_play.bat` exits /b 1 | `ERROR: AAB file not found. Expected: build\app\outputs\bundle\release\app-release.aab. Please run build_release.bat first.` |
| `android\fastlane\play-store-credentials.json` missing | exits /b 1 | `ERROR: play-store-credentials.json not found. Place your service-account JSON at android\fastlane\play-store-credentials.json` |
| `android\Gemfile` missing | exits /b 1 | `ERROR: android\Gemfile not found. Fastlane scaffolding is missing — check the repository setup.` |
| `bundle exec fastlane upload_internal` fails | exits /b 1 | `ERROR: Upload failed. Check the output above.` |
| `key.properties` absent at build time | Gradle falls back to debug signing; build succeeds | No error — AAB built with debug signature (NFR2 safe fallback; Play Store will reject at upload, not at build) |
| `key.properties` present but malformed/wrong path | Gradle error during APK signing configuration | Standard Gradle error; developer must correct `android/key.properties` |
| Duplicate versionCode on Play Store | `build_release.bat` always bumps build number before each build | Not reachable in normal flow; manual deploy-only (menu 3) shows explicit warning |

---

## 7. Test Strategy

### Unit Tests

- Target: No new Dart code introduced; existing Dart/Flutter unit tests are unaffected and must continue to pass.
- Coverage goal: N/A for this feature (all changes are batch scripts, Kotlin Gradle, Ruby).
- Verify with: `flutter analyze` (0 new errors/warnings — NFR1) and `flutter test` (all existing tests pass).

### Integration Tests (Manual — no automated harness for batch scripts)

| ID | Scenario | Steps | Expected Result |
|----|----------|-------|-----------------|
| IT-1 | Build only — no key.properties | Remove `android/key.properties`; run `build_release.bat` | Exits 0; `app-release.aab` and `fitness_timer-v{X.Y.Z}.aab` both exist; `pubspec.yaml` version incremented |
| IT-2 | Build with key.properties | Place valid `key.properties` + keystore; run `build_release.bat` | AAB signed with release key (verify: `apksigner verify --print-certs`) |
| IT-3 | Deploy — missing credentials | Delete `android/fastlane/play-store-credentials.json`; run `deploy_to_play.bat` | Exits 1; prints clear placement guidance |
| IT-4 | Deploy — missing Gemfile | Delete `android/Gemfile`; run `deploy_to_play.bat` | Exits 1; prints clear guidance |
| IT-5 | Deploy — missing AAB | Ensure no `app-release.aab`; run `deploy_to_play.bat` | Exits 1; message says to run `build_release.bat` first |
| IT-6 | Full pipeline (menu 1) | Run `build_and_deploy.bat`, choose 1; credentials in place | Build succeeds, AAB uploaded to Internal Testing |
| IT-7 | Build only (menu 2) | Run `build_and_deploy.bat`, choose 2 | Build succeeds; deploy not attempted |
| IT-8 | Deploy only (menu 3) | Pre-existing AAB; run `build_and_deploy.bat`, choose 3 | Upload attempted; warning shown about no version bump |
| IT-9 | flutter analyze | Run `flutter analyze` from project root after all changes | 0 new errors, 0 new warnings |

### E2E Test Scenarios

- **E2E-1 (Cold start, no credentials):** Developer clones repo with no `key.properties` and no `play-store-credentials.json`. Runs menu [2] (build only). AAB is produced with debug signature. No crash, no confusing error. Actionable guidance is shown only if deploy is attempted.
- **E2E-2 (Fully configured, full pipeline):** Developer places real keystore + key.properties + play-store-credentials.json. Runs menu [1]. pubspec.yaml version increments, release-signed AAB appears in `build/`, Fastlane uploads to Play Console Internal Testing. AAB visible in Play Console within minutes.
- **E2E-3 (Version collision prevention):** Developer runs menu [2] twice back-to-back. Second build shows a higher versionCode than first. Play Store accepts both.

---

## 8. Security Considerations

| Threat | Mitigation |
|--------|------------|
| Keystore committed to repo | `android/key.properties`, `*.jks`, `*.keystore` added to `.gitignore`; only `key.properties.example` (with placeholders) is committed |
| Service-account JSON committed | `android/fastlane/play-store-credentials.json` added to `.gitignore` |
| Dart-define secrets in scripts | `secrets.prod.json` deleted (FR4); all `--dart-define` and `--dart-define-from-file` flags removed (FR1.2) — no secrets at build time |
| Fastlane-generated files exposing data | `android/fastlane/report.xml`, `Preview.html`, auto-generated `README.md` added to `.gitignore` |
| Debug-signed AAB silently published | Without `key.properties` the AAB is debug-signed; Fastlane/Play Store will reject it at upload, not silently accept it — clear failure signal to developer |
| Script injection via pubspec.yaml version | Version parsed with `findstr` + `for /f` extracting only numeric tokens; no shell expansion of user-controlled string content |
| Accidental wipe of gitignore entries | `Gemfile.lock` explicitly left off the gitignore list (intentional commit per Ruby convention) |
