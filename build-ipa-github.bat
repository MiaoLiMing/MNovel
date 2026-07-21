@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

set "REPOSITORY=MiaoLiMing/MNovel"
set "WORKFLOW=build-ios-unsigned.yml"

where git.exe >nul 2>nul
if errorlevel 1 (
  echo Git is not installed or is not available in PATH.
  goto :failed
)

for /f "tokens=2" %%V in ('findstr /b /c:"version:" "apps\mobile\pubspec.yaml"') do set "FULL_VERSION=%%V"
for /f "tokens=1,2 delims=+" %%A in ("%FULL_VERSION%") do (
  set "BUILD_NAME=%%A"
  set "BUILD_NUMBER=%%B"
)
if "%BUILD_NAME%"=="" set "BUILD_NAME=1.0.0"
if "%BUILD_NUMBER%"=="" set "BUILD_NUMBER=1"
if not "%~1"=="" set "BUILD_NAME=%~1"
if not "%~2"=="" set "BUILD_NUMBER=%~2"

for /f "delims=" %%B in ('git branch --show-current') do set "BRANCH=%%B"
if "%BRANCH%"=="" (
  echo Cannot build from a detached HEAD. Switch to a branch first.
  goto :failed
)

set "DIRTY="
for /f "delims=" %%F in ('git status --porcelain') do set "DIRTY=1"
if defined DIRTY (
  echo The working tree contains uncommitted changes.
  echo Commit them first so GitHub Actions builds the same code you see locally.
  goto :failed
)

echo [1/2] Pushing branch "%BRANCH%" to origin...
git push --set-upstream origin "%BRANCH%"
if errorlevel 1 goto :failed

echo [2/2] Starting GitHub Actions workflow...
where gh.exe >nul 2>nul
if not errorlevel 1 goto :use_gh

if "%GH_TOKEN%"=="" (
  echo GitHub CLI is not installed and GH_TOKEN is not configured.
  echo Install GitHub CLI and run "gh auth login", or configure a token once:
  echo   setx GH_TOKEN "YOUR_FINE_GRAINED_GITHUB_TOKEN"
  echo The token needs Actions read/write access to %REPOSITORY%.
  goto :failed
)

curl.exe --fail-with-body --silent --show-error ^
  --request POST ^
  --header "Accept: application/vnd.github+json" ^
  --header "Authorization: Bearer %GH_TOKEN%" ^
  --header "X-GitHub-Api-Version: 2022-11-28" ^
  "https://api.github.com/repos/%REPOSITORY%/actions/workflows/%WORKFLOW%/dispatches" ^
  --data "{\"ref\":\"%BRANCH%\",\"inputs\":{\"build_name\":\"%BUILD_NAME%\",\"build_number\":\"%BUILD_NUMBER%\"}}"
if errorlevel 1 goto :failed
goto :started

:use_gh
gh workflow run "%WORKFLOW%" --repo "%REPOSITORY%" --ref "%BRANCH%" --field "build_name=%BUILD_NAME%" --field "build_number=%BUILD_NUMBER%"
if errorlevel 1 goto :failed

:started
echo.
echo IPA workflow started for %BRANCH%: %BUILD_NAME%+%BUILD_NUMBER%
echo Download MNovel-unsigned.ipa from the workflow artifact after it succeeds.
start "" "https://github.com/%REPOSITORY%/actions/workflows/%WORKFLOW%"
pause
exit /b 0

:failed
echo.
echo IPA workflow was not started.
pause
exit /b 1
