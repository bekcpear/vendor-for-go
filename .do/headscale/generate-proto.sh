#!/usr/bin/env bash
#

pushd ${MOD_DIR}
set -x
rm -rf ./gen
_BUF_CMD="${GOPATH}/bin/buf"
if [[ ! -x ${_BUF_CMD} ]]; then
  go install github.com/bufbuild/buf/cmd/buf@latest
#  deps=(google.golang.org/protobuf/cmd/protoc-gen-go
#        google.golang.org/grpc/cmd/protoc-gen-go-grpc
#        github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-openapiv2
#        github.com/grpc-ecosystem/grpc-gateway/v2/protoc-gen-grpc-gateway)
#  for dep in ${deps[@]}; do
#    go install ${dep} || \
#      go install ${dep}@latest
#  done
fi
${_BUF_CMD} generate proto

if [[ -d "${VCS_DIR}" ]]; then
  rm -rf "${VCS_DIR%/}/gen"
fi
cp -a ./gen ${VCS_DIR%/}${VCS_DIR:+/}
git -C ${VCS_DIR} add ./gen
git -C ${VCS_DIR} commit -m "gen: update generated proto for ${VERSION}"
popd
