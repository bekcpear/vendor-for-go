#!/usr/bin/env bash
#

if [[ $1 == '-h' ]]; then
  echo "
  Example:
      ${0##*/} headscale 0.17.0 ~/Git/gopkg-vendors
"
  exit
fi

_FIND_PATH="/var/cache/distfiles"

_THIS_PATH=$(dirname $(realpath $0))

_PKG_NAME=${1}
_MOD_VER=${2}
_VCS_DIR=${3}

_PKG_PATH=$(ls -1 ${_FIND_PATH%/}/${_PKG_NAME}-${_MOD_VER}.tar.*)
[[ -z ${_PKG_PATH} ]] && \
  _PKG_PATH=$(ls -1 ${_FIND_PATH%/}/${_PKG_NAME}-${_MOD_VER//-/_}.tar.*)
[[ -z ${_PKG_PATH} ]] && \
  {
    echo "cannot find pkg tarball for '${_PKG_NAME}'" >&2
    exit 1
  }

set -e
_TMPDIR=$(mktemp -d)
tar -C ${_TMPDIR} -xf ${_PKG_PATH}
_MOD_DIR=$(ls -1d ${_TMPDIR}/*)

_PKG_ARGS=$(cat ${_THIS_PATH}/${_PKG_NAME}/ARGS 2>/dev/null || true)
_PKG_ARGS=${_PKG_ARGS//%MYDIR%/${_THIS_PATH}/${_PKG_NAME}}

eval "${_THIS_PATH}/../gen.sh -b${_PKG_NAME} -u ${_PKG_ARGS} -p \"${_VCS_DIR}\" \"${_MOD_DIR}\" ${_MOD_VER}"

rm -rf "${_TMPDIR}"
