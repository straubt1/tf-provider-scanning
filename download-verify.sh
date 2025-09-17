#!/usr/bin/env bash

# Script to download and verify Terraform provider
# Usage: ./download-verify.sh <provider-name> <version>

# Note: Unzipping certain provider repos has caused some issues

set -euo pipefail

# -- colored output helpers -------------------------------------------------
# Only enable colors when stdout is a terminal
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  MAGENTA='\033[0;35m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  MAGENTA=''
  CYAN=''
  BOLD=''
  RESET=''
fi

info()   { printf "%b\n" "${BOLD}${CYAN}==> ${1}${RESET}"; }
step()   { printf "%b\n" "${BOLD}${BLUE}--> ${1}${RESET}"; }
success(){ printf "%b\n" "${BOLD}${GREEN}✔  ${1}${RESET}"; }
warn()   { printf "%b\n" "${BOLD}${YELLOW}⚠  ${1}${RESET}"; }
err()    { printf "%b\n" "${BOLD}${RED}✖  ${1}${RESET}"; }


if [ $# -ne 2 ]; then
  err "Usage: $0 <provider-name> <version>"
  step "Example: $0 aws 4.57.1"
  exit 1
fi

NAME="$1"
VERSION="$2"
PLATFORM="linux_amd64"
GITHUB_ORG="hashicorp"

# Base URL for releases
BASE_URL="https://releases.hashicorp.com/terraform-provider-${NAME}/${VERSION}"
ZIP_FILE="terraform-provider-${NAME}_${VERSION}_${PLATFORM}.zip"
SUMS_FILE="terraform-provider-${NAME}_${VERSION}_SHA256SUMS"
SUMS_SIG_FILE="terraform-provider-${NAME}_${VERSION}_SHA256SUMS.sig"
PROVIDER_FILE="terraform-provider-${NAME}_v${VERSION}_x5"

BASE_GIT_URL="https://github.com/${GITHUB_ORG}/terraform-provider-${NAME}/archive/refs/tags/"
GIT_ZIP_FILE="v${VERSION}.zip"
GIT_CODE_FOLDER="terraform-provider-${NAME}-${VERSION}"

DOWNLOAD_DIR="download/${NAME}/${VERSION}"
RELEASE_DIR="release/${NAME}/${VERSION}/${PLATFORM}"
mkdir -p "$DOWNLOAD_DIR"

info "Downloading Terraform provider files: ${NAME} version ${VERSION} for ${PLATFORM}"
if [ ! -f "${DOWNLOAD_DIR}/${ZIP_FILE}" ]; then
  curl \
  -sL "${BASE_URL}/${ZIP_FILE}" \
  -o "${DOWNLOAD_DIR}/${ZIP_FILE}"
fi

if [ ! -f "${DOWNLOAD_DIR}/${SUMS_FILE}" ]; then
  curl \
  -sL "${BASE_URL}/${SUMS_FILE}" \
  -o "${DOWNLOAD_DIR}/${SUMS_FILE}"
fi

if [ ! -f "${DOWNLOAD_DIR}/${SUMS_SIG_FILE}" ]; then
  curl \
  -sL "${BASE_URL}/${SUMS_SIG_FILE}" \
  -o "${DOWNLOAD_DIR}/${SUMS_SIG_FILE}"
fi

# Verify checksum using sha256sum if available, otherwise use shasum
info "Verifying checksum..."
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$DOWNLOAD_DIR" && sha256sum -c "$SUMS_FILE" --ignore-missing)
elif command -v shasum >/dev/null 2>&1; then
  if ! (cd "$DOWNLOAD_DIR" && shasum -a 256 -c "$SUMS_FILE"); then
    err "Checksum verification failed using shasum."
    exit 1
  fi
else
  err "No sha256 verifier available (sha256sum or shasum)."
  exit 1
fi

info "Verifying GPG signature..."
gpg --verify "${DOWNLOAD_DIR}/${SUMS_SIG_FILE}" "${DOWNLOAD_DIR}/${SUMS_FILE}" || true

info "Unzipping provider..."
7z x "$DOWNLOAD_DIR/$ZIP_FILE" -o./${DOWNLOAD_DIR} -y -bd 2>/dev/null || true

step "Copying $PROVIDER_FILE to $DOWNLOAD_DIR"
mkdir -p "$RELEASE_DIR"
cp -f "${DOWNLOAD_DIR}/${PROVIDER_FILE}" "${RELEASE_DIR}/${PROVIDER_FILE}"

info "Scanning for provider files (grype)..."
grype "${RELEASE_DIR}/${PROVIDER_FILE}" || true

info "Scanning for provider files (govulncheck)..."
govulncheck -mode binary "${RELEASE_DIR}/${PROVIDER_FILE}" || true

info "Downloading repository source..."
if [ ! -f "${DOWNLOAD_DIR}/${GIT_ZIP_FILE}" ]; then
  curl \
  -sL "${BASE_GIT_URL}/${GIT_ZIP_FILE}" \
  -o "${DOWNLOAD_DIR}/${GIT_ZIP_FILE}"
fi

step "Unzipping code..."
7z x "$DOWNLOAD_DIR/$GIT_ZIP_FILE" -o./${DOWNLOAD_DIR} -y -bd 2>/dev/null

info "Scanning source code for vulnerabilities..."
govulncheck -mode source -C "${DOWNLOAD_DIR}/${GIT_CODE_FOLDER}" "./..." || true

info "Scanning source code for secrets..."
gitleaks dir "${DOWNLOAD_DIR}/${GIT_CODE_FOLDER}" || true

success "All done!"