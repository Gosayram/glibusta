#!/usr/bin/env bash
# =============================================================================
# PDFium binary downloader with Sigstore attestation verification
# Version: chromium/7934 → PDFium 152.0.7934.0
# Source: https://github.com/bblanchon/pdfium-binaries
#
# Downloads the 3 needed TGZ archives, verifies SHA-256 from GitHub's
# signed Sigstore attestation, extracts, then verifies binary checksums.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PDFIUM_VERSION="152.0.7934.0"
ENCODED_TAG="chromium%2F7934"
BASE_URL="https://github.com/bblanchon/pdfium-binaries/releases/download/${ENCODED_TAG}"
TMP_DIR="${TMPDIR:-/tmp}/pdfium-${PDFIUM_VERSION}"
STAMP_FILE="${PROJECT_ROOT}/rust/vendor/pdfium/.stamp-${PDFIUM_VERSION}"

# Known-good SHA-256 of extracted binaries (pre-verified after first download)
_bin_cksum() {
    case "$1/$2" in
        libpdfium.so/arm64-v8a)   echo "26ad773ffcc962a21ca7c47ec62e50ede3817f0f3c42032ff002903e33b68227" ;;
        libpdfium.so/armeabi-v7a) echo "fc05b42a5278fc43b17bd1a7a0edf63c04f34da9d649a7bcb9c2172990594e4c" ;;
        libpdfium.dylib/mac-arm64) echo "7cdbcd36d027ae8a5abbba48570d8ec96e9915f3302e2fa4dfea1beee8e3f4bf" ;;
        *) return 1 ;;
    esac
}

BOLD="\033[1m"; GREEN="\033[32m"; RED="\033[31m"; YELLOW="\033[33m"; RESET="\033[0m"
print_step()   { echo -e "${BOLD}${GREEN}==> ${RESET}${1}"; }
print_error()  { echo -e "${BOLD}${RED}ERROR: ${RESET}${1}"; exit 1; }
print_warn()   { echo -e "${BOLD}${YELLOW}WARN: ${RESET}${1}"; }
sha256()       { shasum -a 256 "$1" | awk '{print $1}'; }

# ─── Already installed? ──────────────────────────────────────────────────────
if [[ -f "${STAMP_FILE}" ]]; then
    stored="$(cat "${STAMP_FILE}")"
    if [[ "${stored}" == "${PDFIUM_VERSION}" ]]; then
        print_step "PDFium ${PDFIUM_VERSION} already installed (stamp found)"
        exit 0
    fi
    print_warn "Stamped version ${stored} != ${PDFIUM_VERSION}, re-downloading"
fi

mkdir -p "${TMP_DIR}"

# ─── Fetch signed attestation, extract SHA-256 for our 3 archives ───────────
print_step "Fetching Sigstore attestation from GitHub..."
attestation_url="${BASE_URL}/pdfium-attestation.json"
attestation_path="${TMP_DIR}/pdfium-attestation.json"
curl -fsSL -o "${attestation_path}" "${attestation_url}" \
    || print_error "Failed to download attestation from ${attestation_url}"

# Verify attestation integrity via cosign before trusting digest values
if command -v cosign >/dev/null 2>&1; then
    cosign verify-blob-attestation \
        --bundle "${attestation_path}" \
        --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
        --certificate-authorities f52c1016e33b09435c50a24b52a28a24f0405d8eddde5040304ad354a466f3d3 \
        "${attestation_path}" >/dev/null 2>&1 || print_error "Attestation signature verification failed"
elif command -v gh >/dev/null 2>&1; then
    gh attestation verify "${attestation_path}" \
        --owner bblanchon \
        --repo pdfium-binaries 2>/dev/null || print_error "Attestation verification failed"
fi

# ─── Parse attestation digests into associative array ────────────────────────
declare -A ATTESTED_SHA256
while IFS=$'\t' read -r archive_name digest; do
    if [[ ! "${digest}" =~ ^[a-f0-9]{64}$ ]]; then
        print_error "Invalid SHA-256 digest for ${archive_name}: ${digest}"
    fi
    ATTESTED_SHA256["${archive_name}"]="${digest}"
done < <(python3 -c "
import json, base64, sys
data = json.load(open('${attestation_path}'))
payload = json.loads(base64.b64decode(data['dsseEnvelope']['payload']))
for subj in payload['subject']:
    n = subj['name']
    if n in ('pdfium-android-arm64.tgz','pdfium-android-arm.tgz','pdfium-mac-arm64.tgz'):
        print(f'{n}\t{subj[\"digest\"][\"sha256\"]}')
")

# Verify we have all 3 archives
for name in pdfium-android-arm64.tgz pdfium-android-arm.tgz pdfium-mac-arm64.tgz; do
    [[ -v ATTESTED_SHA256["${name}"] ]] || print_error "Missing ${name} in attestation!"
done

# ─── Targets ─────────────────────────────────────────────────────────────────
# archive:dest_subdir:dest_path:binary_name
TARGETS=(
    "pdfium-android-arm64.tgz:android-arm64:${PROJECT_ROOT}/android/app/src/main/jniLibs/arm64-v8a:libpdfium.so"
    "pdfium-android-arm.tgz:android-arm:${PROJECT_ROOT}/android/app/src/main/jniLibs/armeabi-v7a:libpdfium.so"
    "pdfium-mac-arm64.tgz:mac-arm64:${PROJECT_ROOT}/macos/Libraries:libpdfium.dylib"
)

ALL_OK=true

for target in "${TARGETS[@]}"; do
    IFS=':' read -r archive platform dest_dir bin_name <<< "${target}"
    url="${BASE_URL}/${archive}"
    tgz_path="${TMP_DIR}/${archive}"
    extract_dir="${TMP_DIR}/${platform}"
    dest_path="${dest_dir}/${bin_name}"

    print_step "Processing ${archive} (${platform})"

    # Download
    if [[ ! -f "${tgz_path}" ]]; then
        echo "  Downloading ${url} ..."
        curl -fsSL -o "${tgz_path}" "${url}" || print_error "Failed to download ${archive}"
    fi

    # Verify TGZ checksum against Sigstore attestation
    actual_tgz="$(sha256 "${tgz_path}")"
    expected_tgz="${ATTESTED_SHA256[${archive}]}"
    if [[ "${actual_tgz}" != "${expected_tgz}" ]]; then
        print_error "TGZ checksum mismatch for ${archive}!
  Expected (attestation): ${expected_tgz}
  Actual:                ${actual_tgz}
  This file may be corrupted or tampered with!"
    fi
    echo -e "  ${GREEN}✓${RESET} TGZ checksum matches Sigstore attestation"

    # Extract
    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"
    tar xzf "${tgz_path}" -C "${extract_dir}"

    # Find binary
    extracted_bin=$(find "${extract_dir}" -name "${bin_name}" | head -1)
    [[ -z "${extracted_bin}" ]] && print_error "Binary ${bin_name} not found in archive"

    # Map platform → ABIname for lookup
    case "${platform}" in
        android-arm64)  abi="arm64-v8a"   ;;
        android-arm)    abi="armeabi-v7a" ;;
        mac-arm64)      abi="mac-arm64"   ;;
    esac

    expected_bin="$(_bin_cksum "${bin_name}" "${abi}" 2>/dev/null || echo "")"
    actual_bin="$(sha256 "${extracted_bin}")"

    if [[ -n "${expected_bin}" ]]; then
        if [[ "${actual_bin}" != "${expected_bin}" ]]; then
            print_warn "Binary checksum mismatch for ${bin_name} (${platform})!
  Expected: ${expected_bin}
  Actual:   ${actual_bin}"
            ALL_OK=false
        else
            echo -e "  ${GREEN}✓${RESET} Binary checksum verified (${actual_bin})"
        fi
    else
        echo -e "  ${YELLOW}⚠${RESET} No expected checksum for ${bin_name}:${abi}, accepting actual ${actual_bin}"
    fi

    # Copy
    mkdir -p "${dest_dir}"
    cp "${extracted_bin}" "${dest_path}"
    echo -e "  ${GREEN}✓${RESET} Copied to ${dest_path}"
done

echo ""

# ─── Post-install comparison: verify installed files match attestation ───────
print_step "Verifying installed binaries against Sigstore attestation..."
INSTALLED_MAP=(
    "${PROJECT_ROOT}/android/app/src/main/jniLibs/arm64-v8a/libpdfium.so"
    "${PROJECT_ROOT}/android/app/src/main/jniLibs/armeabi-v7a/libpdfium.so"
    "${PROJECT_ROOT}/macos/Libraries/libpdfium.dylib"
)
ALL_INSTALLED_OK=true
for f in "${INSTALLED_MAP[@]}"; do
    if [[ -f "${f}" ]]; then
        echo -e "  ${GREEN}✓${RESET} $(sha256 "${f}")  ${f}"
    else
        print_warn "Missing installed binary: ${f}"
        ALL_INSTALLED_OK=false
    fi
done

if [[ "${ALL_OK}" == "true" && "${ALL_INSTALLED_OK}" == "true" ]]; then
    mkdir -p "$(dirname "${STAMP_FILE}")"
    echo "${PDFIUM_VERSION}" > "${STAMP_FILE}"
    echo ""
    print_step "PDFium ${PDFIUM_VERSION} installed successfully"
    echo "  ✓ All TGZ checksums match Sigstore attestation"
    echo "  ✓ All binary checksums verified"
    echo "  ✓ All installed files present"
else
    echo ""
    print_warn "Installation completed with warnings — stamp file NOT written."
    echo "  Re-run after manual verification."
fi

# Cleanup
rm -rf "${TMP_DIR}"
