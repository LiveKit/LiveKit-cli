#!/usr/bin/env bash
# LiveKit install script for Linux

set -u
set -o errtrace
set -o errexit
set -o pipefail

REPO="livekit-cli"
INSTALL_PATH="/usr/local/bin"
BASH_COMPLETION_PATH="/usr/share/bash-completion/completions"
ZSH_COMPLETION_PATH="/usr/share/zsh/site-functions"
FISH_COMPLETION_PATH="/usr/share/fish/vendor_completions.d"

log()  { printf "%b\n" "$*"; }
abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# returns the latest version according to GH
# i.e. 1.0.0
get_latest_version()
{
  latest_version=$(curl -s https://api.github.com/repos/livekit/$REPO/releases/latest | grep -oP '"tarball_url": ".*/tarball/v\K([^/]*)(?=")')
  printf "%s" "$latest_version"
}

# Ensure bash is used
if [ -z "${BASH_VERSION:-}" ]
then
  abort "This script requires bash"
fi

# Check if $INSTALL_PATH exists
if [ ! -d ${INSTALL_PATH} ]
then
  abort "Could not install, ${INSTALL_PATH} doesn't exist"
fi

# Needs SUDO if no permissions to write
SUDO_PREFIX=""
if [ ! -w ${INSTALL_PATH} ]
then
  SUDO_PREFIX="sudo"
  log "sudo is required to install to ${INSTALL_PATH}"
fi

# Check cURL is installed
if ! command -v curl >/dev/null
then
  abort "cURL is required and is not found"
fi

# OS check
OS="$(uname)"
if [[ "${OS}" == "Darwin" ]]
then
  abort "Installer not supported on MacOS, please install using Homebrew."
elif [[ "${OS}" != "Linux" ]]
then
  abort "Installer is only supported on Linux."
fi

ARCH="$(/usr/bin/uname -m)"

# fix arch on linux
if [[ "${ARCH}" == "aarch64" ]]
then
  ARCH="arm64"
elif [[ "${ARCH}" == "x86_64" ]]
then
  ARCH="amd64"
fi

VERSION=$(get_latest_version)
ARCHIVE_URL="https://github.com/livekit/$REPO/releases/download/v${VERSION}/${REPO}_${VERSION}_linux_${ARCH}.tar.gz"

# Ensure version follows SemVer
if ! [[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
then
  abort "Invalid version: ${VERSION}"
fi

log "Installing ${REPO} ${VERSION}"
log "Downloading from ${ARCHIVE_URL}..."

TEMP_DIR_PATH="$(mktemp -d)"

curl -s -L "${ARCHIVE_URL}" | ${SUDO_PREFIX} tar xzf - -C "${TEMP_DIR_PATH}" --wildcards --no-anchored "$REPO*"

mv "${TEMP_DIR_PATH}/livekit-cli" "${INSTALL_PATH}/livekit-cli"

if [ -d "${TEMP_DIR_PATH}/autocomplete" ]
then
  if [ -d "${BASH_COMPLETION_PATH}" ]
  then
    mv "${TEMP_DIR_PATH}/autocomplete/bash_autocomplete" "${BASH_COMPLETION_PATH}/livekit-cli"
  fi

  if [ -d "${ZSH_COMPLETION_PATH}" ]
  then
    mv "${TEMP_DIR_PATH}/autocomplete/zsh_autocomplete" "${BASH_COMPLETION_PATH}/_livekit-cli"
  fi

  if [ -d "${FISH_COMPLETION_PATH}" ]
  then
    livekit-cli generate-fish-completion -o "${FISH_COMPLETION_PATH}/livekit-cli.fish"
  fi
fi

log "\n$REPO is installed to $INSTALL_PATH\n"
