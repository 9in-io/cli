# Installs the 9in CLI on Windows.
#
#   irm https://raw.githubusercontent.com/9in-io/cli/master/install.ps1 | iex
#
# Environment:
#   NINE_VERSION       version to install (default: the latest release), e.g. 2.0.0
#   NINE_INSTALL_DIR   where to put 9in.exe (default: %LOCALAPPDATA%\Programs\9in)
$ErrorActionPreference = 'Stop'
$repo = '9in-io/cli'

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
  'AMD64' { 'amd64' }
  'ARM64' { 'arm64' }
  default { throw "9in install: unsupported architecture $($env:PROCESSOR_ARCHITECTURE) (builds exist for amd64 and arm64)" }
}

$version = $env:NINE_VERSION
if (-not $version) {
  $release = Invoke-RestMethod -UseBasicParsing -Headers @{ 'User-Agent' = '9in-install' } "https://api.github.com/repos/$repo/releases/latest"
  $version = $release.tag_name
}
$version = $version.TrimStart('v')

$archive = "9in_${version}_windows_${arch}.zip"
$base = "https://github.com/$repo/releases/download/v$version"
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("9in-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Write-Host "Downloading 9in $version for windows/$arch"
  Invoke-WebRequest -UseBasicParsing "$base/$archive" -OutFile (Join-Path $tmp $archive)
  Invoke-WebRequest -UseBasicParsing "$base/checksums.txt" -OutFile (Join-Path $tmp 'checksums.txt')

  $line = Get-Content (Join-Path $tmp 'checksums.txt') | Where-Object { $_ -match "\s$([regex]::Escape($archive))$" } | Select-Object -First 1
  if (-not $line) { throw "9in install: checksums.txt does not list $archive" }
  $expected = ($line -split '\s+')[0].ToLower()
  $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $tmp $archive)).Hash.ToLower()
  if ($expected -ne $actual) { throw "9in install: checksum mismatch for $archive; nothing was installed" }

  Expand-Archive -Path (Join-Path $tmp $archive) -DestinationPath (Join-Path $tmp 'x') -Force
  $dir = $env:NINE_INSTALL_DIR
  if (-not $dir) { $dir = Join-Path $env:LOCALAPPDATA 'Programs\9in' }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $target = Join-Path $dir '9in.exe'
  if (Test-Path $target) {
    # A running 9in.exe cannot be overwritten, but it can be renamed.
    Move-Item -Force $target "$target.old"
  }
  Copy-Item (Join-Path $tmp 'x\9in.exe') $target

  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not (($userPath -split ';') -contains $dir)) {
    [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ";$dir").TrimStart(';'), 'User')
    Write-Host "Added $dir to your PATH (open a new terminal to use it)."
  }
  Write-Host "Installed 9in $version to $target"
  Write-Host 'Get started: 9in login'
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
