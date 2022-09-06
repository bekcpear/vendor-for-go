#!/usr/bin/env bash
#

# quic-go and assume-no-moving-gc are tierd to the version
# of the go compiler, but over time, there is no guarantee
# that quic-go will be updated instantly every time, so it
# should be checked when package v2ray-core and use the
# updated go.mod and go.sum
cp -a "${MOD_DIR}"/go.* "${VCS_DIR}"/
pushd "${VCS_DIR}"
git add go.*
git commit -m "update go.mod and go.sum"
