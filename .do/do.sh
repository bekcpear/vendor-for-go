#!/usr/bin/env bash
#

if [[ $* =~ (^|[[:space:]])-h([[:space:]]|$) ]]; then
  echo "
  Example:
      ${0##*/} ~/Git/gopkg-vendors headscale 0.17.0
"
  exit
fi

_FIND_PATH="/var/cache/distfiles"

_THIS_PATH=$(dirname $(realpath $0))

_VCS_DIR=${1}
_PKG_NAME=${2%/*}
_PKG_SUBDIR=${2#${_PKG_NAME}}
_PKG_SUBDIR=${_PKG_SUBDIR#/}
_MOD_VER=${3}

if [[ -z ${_PKG_PATH} ]]; then
  _PKG_PATH=$(ls -1 ${_FIND_PATH%/}/${_PKG_NAME}-${_MOD_VER}.tar.*)
  [[ -z ${_PKG_PATH} ]] && \
    _PKG_PATH=$(ls -1 ${_FIND_PATH%/}/${_PKG_NAME}-${_MOD_VER//-/_}.tar.*)
  [[ -z ${_PKG_PATH} ]] && \
    {
      echo "cannot find pkg tarball for '${_PKG_NAME}'" >&2
      exit 1
    }
fi

set -e
_TMPDIR=$(mktemp -d)
tar -C ${_TMPDIR} -xf ${_PKG_PATH}
_MOD_DIR="$(ls -1d ${_TMPDIR}/*)${_PKG_SUBDIR:+/}${_PKG_SUBDIR}"

_PKG_ARGS=$(cat ${_THIS_PATH}/${_PKG_NAME}/ARGS 2>/dev/null || true)
_PKG_ARGS=${_PKG_ARGS//%MYDIR%/${_THIS_PATH}/${_PKG_NAME}}

eval "${_THIS_PATH}/../gen.sh -b${_PKG_NAME} -u${_EXTRA_PUSH_ARGS:+"}${_EXTRA_PUSH_ARGS}${_EXTRA_PUSH_ARGS:+"} ${_PKG_ARGS} -p \"${_VCS_DIR}\" \"${_MOD_DIR}\" ${_MOD_VER}"

if [[ -z ${4} ]]; then
  rm -rf "${_TMPDIR}"
fi
