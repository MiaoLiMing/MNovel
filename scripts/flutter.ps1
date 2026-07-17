param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]] $FlutterArgs
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $projectRoot '.flutter-version') -Raw).Trim()

$flutterRoot = if ($env:FLUTTER_SDK) {
    $env:FLUTTER_SDK
} else {
    "D:\work\software\flutterFiles\flutter_windows_$version-stable\flutter"
}

$javaHome = if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
    $env:JAVA_HOME
} else {
    'D:\work\software\java\microsoft-jdk-21.0.11\PFiles64\Microsoft\jdk-21.0.11.10-hotspot'
}

$flutter = Join-Path $flutterRoot 'bin\flutter.bat'
if (-not (Test-Path -LiteralPath $flutter)) {
    throw "Flutter $version 未安装：$flutter"
}
if (-not (Test-Path -LiteralPath (Join-Path $javaHome 'bin\java.exe'))) {
    throw "JDK 21 未安装：$javaHome"
}

$env:JAVA_HOME = $javaHome
$env:Path = "$(Join-Path $javaHome 'bin');$(Join-Path $flutterRoot 'bin');$env:Path"

& $flutter --no-version-check @FlutterArgs
exit $LASTEXITCODE

