#!/usr/bin/env bash
#

# quic-go and assume-no-moving-gc are tierd to the version
# of the go compiler, but over time, there is no guarantee
# that quic-go will be updated instantly every time, so it
# should be checked when package v2ray-core and use the
# updated go.mod and go.sum
pushd "${MOD_DIR}"
go get -u go4.org/unsafe/assume-no-moving-gc
go get -u github.com/lucas-clemente/quic-go
