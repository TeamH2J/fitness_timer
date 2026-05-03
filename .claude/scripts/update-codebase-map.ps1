#requires -Version 5.1
# PreToolUse hook: auto-update docs/guidelines/CODEBASE_MAP.md before a git commit
# that touches lib/, so the map update lands in the same commit.

$ErrorActionPreference = 'Stop'

# Resolve project root from script location (.claude/scripts/ → ..\..).
# Falls back to $env:CLAUDE_PROJECT_DIR if PSScriptRoot is unavailable.
if ($PSScriptRoot) {
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
} elseif ($env:CLAUDE_PROJECT_DIR) {
    $projectRoot = $env:CLAUDE_PROJECT_DIR
} else {
    exit 0
}
$mapPath = 'docs/guidelines/CODEBASE_MAP.md'

try {
    $raw = [Console]::In.ReadToEnd()
    if (-not $raw) { exit 0 }
    $inputJson = $raw | ConvertFrom-Json
} catch {
    # Malformed input — never block the user's commit.
    exit 0
}

# Filter 1: Bash tool only.
if ($inputJson.tool_name -ne 'Bash') { exit 0 }

# Filter 2: command must be a git commit (covers `git commit`, `git commit -m`, amend, etc.).
$cmd = [string]$inputJson.tool_input.command
if (-not $cmd) { exit 0 }
if ($cmd -notmatch '\bgit\s+commit\b') { exit 0 }

Set-Location $projectRoot

# Filter 3: staged diff must contain at least one lib/ file.
$staged = & git diff --cached --name-only 2>$null
if ($LASTEXITCODE -ne 0) { exit 0 }
$libTouched = $staged | Where-Object { $_ -match '^lib/' }
if (-not $libTouched) { exit 0 }

$prompt = @'
docs/guidelines/CODEBASE_MAP.md 를 현재 lib/ 구조에 맞게 업데이트해줘.

규칙:
1. 먼저 `git diff --cached --name-only` 로 이번 커밋이 건드리는 lib/ 파일 목록을 확인.
2. 변경된 파일들을 Read 로 읽어 새 클래스/함수가 추가되었는지, 파일이 이동·삭제되었는지 파악.
3. CODEBASE_MAP.md 의 §2 (Directory Tree), §6 (Class ↔ File Lookup) 은 실제 lib/ 트리와 일치하도록 갱신.
4. §3 (Domain Map), §5 (Decision Guide) 는 의미 변화가 있을 때만 최소 수정.
5. §1, §4, §7, §8 은 큰 변화가 없으면 건드리지 말 것.
6. CLAUDE.md §3 (Surgical Changes) 정신을 지켜 — 불필요한 재작성 금지.

작업 후 변경 사항을 한 줄로 요약해서 출력.
'@

try {
    & claude -p $prompt `
        --permission-mode acceptEdits `
        --add-dir $projectRoot | Out-Null

    if (Test-Path $mapPath) {
        & git add -- $mapPath | Out-Null
    }
} catch {
    [Console]::Error.WriteLine("[CODEBASE_MAP auto-update failed] $($_.Exception.Message)")
}

exit 0
