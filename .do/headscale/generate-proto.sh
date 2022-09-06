#!/usr/bin/env bash
#

pushd ${MOD_DIR}
set -x
rm -rf ./gen
_BUF_CMD="${GOPATH}/bin/buf"
if [[ ! -x ${_BUF_CMD} ]]; then
  go install github.com/bufbuild/buf/cmd/buf@latest
  go install google.golang.org/protobuf/cmd/protoc-gen-go
  go install google.golang.org/grpc/cmd/protoc-gen-go-grpc
  go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2
  go install github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway
fi
${_BUF_CMD} generate proto
cp -a ./gen ${VCS_DIR%/}${VCS_DIR:+/}
git -C ${VCS_DIR} add ./gen
git -C ${VCS_DIR} commit -m 'gen: add generated proto'
popd
