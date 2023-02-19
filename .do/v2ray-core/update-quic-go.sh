#!/usr/bin/env bash
#

# quic-go is tierd to the version of the go compiler and is
# directly depended by github.com/v2fly/v2ray-core/v5/app/dns,
# but over time, there is no guarantee
# that quic-go will be updated instantly every time, so it
# should be checked when package v2ray-core and use the
# updated go.mod and go.sum
pushd "${MOD_DIR}"
go get github.com/quic-go/quic-go@latest
