#!/bin/bash
REPO_USER="netbirdio"
REPO_MAIN="netbird"

getLatestRelease() {
  curl --silent \
    "https://api.github.com/repos/${REPO_USER}/${REPO_MAIN}/releases/latest" \
    | grep tag_name \
    | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g'
}
VERSION=$(getLatestRelease)

mkdir -p "${VERSION}" || exit
cd "${VERSION}" || exit

for i in $(curl https://api.github.com/repos/netbirdio/netbird/releases/latest | jq -r '.assets[].name'); do
  curl -Lf --output "${i}" "https://github.com/netbirdio/netbird/releases/download/v${VERSION}/${i}"
done

sha256sum -c "netbird_${VERSION}_checksums.txt"
sha256sum -c "netbird-ui_${VERSION}_checksums.txt"
sha256sum -c "netbird-ui_darwin_checksums.txt"