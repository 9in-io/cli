#!/bin/sh
# Installs the 9in CLI on macOS and Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/9in-io/cli/master/install.sh | sh
#
# Environment:
#   NINE_VERSION       version to install (default: the latest release), e.g. 2.0.0
#   NINE_INSTALL_DIR   where to put the binary (default: /usr/local/bin if writable, else ~/.local/bin)
set -eu

REPO="9in-io/cli"

fail() {
  echo "9in install: $*" >&2
  exit 1
}

need() {
  command -v "$1" >/dev/null 2>&1 || fail "this script needs '$1'"
}

need uname
need tar
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fsSL --retry 3 "$1"; }
  download() { curl -fsSL --retry 3 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -qO- "$1"; }
  download() { wget -qO "$2" "$1"; }
else
  fail "this script needs curl or wget"
fi

case "$(uname -s)" in
  Darwin) os=darwin ;;
  Linux) os=linux ;;
  MINGW* | MSYS* | CYGWIN*) fail "on Windows, run in PowerShell: irm https://raw.githubusercontent.com/$REPO/master/install.ps1 | iex" ;;
  *) fail "unsupported operating system: $(uname -s)" ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) arch=amd64 ;;
  arm64 | aarch64) arch=arm64 ;;
  *) fail "unsupported architecture: $(uname -m) (builds exist for amd64 and arm64)" ;;
esac

version="${NINE_VERSION:-}"
if [ -z "$version" ]; then
  version="$(fetch "https://api.github.com/repos/$REPO/releases/latest" | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$version" ] || fail "could not find the latest release of $REPO"
fi
version="${version#v}"

archive="9in_${version}_${os}_${arch}.tar.gz"
base="https://github.com/$REPO/releases/download/v${version}"
tmp="$(mktemp -d 2>/dev/null || mktemp -d -t 9in)"
trap 'rm -rf "$tmp"' EXIT INT TERM

echo "Downloading 9in $version for $os/$arch"
download "$base/$archive" "$tmp/$archive" || fail "could not download $base/$archive"
download "$base/checksums.txt" "$tmp/checksums.txt" || fail "could not download checksums.txt"

expected="$(grep " $archive\$" "$tmp/checksums.txt" | cut -d ' ' -f 1)"
[ -n "$expected" ] || fail "checksums.txt does not list $archive"
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum "$tmp/$archive" | cut -d ' ' -f 1)"
elif command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$tmp/$archive" | cut -d ' ' -f 1)"
else
  fail "this script needs sha256sum or shasum to verify the download"
fi
[ "$expected" = "$actual" ] || fail "checksum mismatch for $archive; nothing was installed"

tar -xzf "$tmp/$archive" -C "$tmp" 9in || fail "could not extract the archive"

dir="${NINE_INSTALL_DIR:-}"
if [ -z "$dir" ]; then
  if [ -w /usr/local/bin ]; then
    dir=/usr/local/bin
  else
    dir="$HOME/.local/bin"
  fi
fi
mkdir -p "$dir" || fail "could not create $dir"
if ! mv "$tmp/9in" "$dir/9in" 2>/dev/null; then
  fail "could not write to $dir; set NINE_INSTALL_DIR or run with the needed permissions"
fi
chmod 755 "$dir/9in"

echo "Installed 9in $version to $dir/9in"
case ":$PATH:" in
  *":$dir:"*) ;;
  *) echo "Add $dir to your PATH, for example: echo 'export PATH=\"$dir:\$PATH\"' >> ~/.profile" ;;
esac
echo "Get started: 9in login"
