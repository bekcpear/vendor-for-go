#!/usr/bin/env bash
#
# @author: cwittlut <i@bitbili.net>
#

_help() {
  echo "
Usage: $(basename $0) [<PKG-DIR> [<PKG-VERSION>]] [<OPTS>...]

  If no <PKG-DIR> provided, the current path will be used.
  If no <PKG-VERSION> provided, this script will skip git actions,
                                unless '-b' is used, which forces the checkout action.

    -p  <path>        The parent path of the output 'vendor' (the VCS dir)
                       if omitted, it defaults to <PKG-DIR>,
                                   and other actions of this script will be ignored
    -P                Flag the <path> above is a parent path of the VCS dir,
                       and the VCS path will be generated by the module path
                       **it conflicts with '-b'**
    -b[<name>]        store the vendor dir of different modules in different branchs
                       of a single VCS dir; if the <name> is omitted, it will be
                       generated by the base path of the module path; the tag name
                       will be prefixed by the branch name
                       **it conflicts with '-P'**
    -u[<args>]        auto push to upstream with optional <args> (quote them)
    -g  <ver>         Update the go directive to the indicated version
    -v                Verbose output
"
}

set +e
unset GETOPT_COMPATIBLE
getopt -T
if [[ ${?} != 4 ]]; then
  echo "The command 'getopt' of Linux version is necessory to parse parameters." >&2
  exit 1
fi
_ARGS=$(getopt -o 'g:p:u::b::Pv' -- "$@")
if [[ ${?} != 0 ]]; then
  _help
  exit 1
fi
set -e

_PUSH_ARGS="--follow-tags"
eval "set -- ${_ARGS}"
while :; do
  case "${1}" in
    -g)
      shift
      _GO_VER="${1}"
      shift
      ;;
    -p)
      shift
      _VCS_DIR="$(realpath ${1})"
      shift
      ;;
    -b)
      if [[ -n ${_AUTOGEN} ]]; then
        echo "'-b' conflicts with '-P'" >&2
        exit 1
      fi
      _USE_BRANCH=1
      shift
      _BRANCH_NAME="${1}"
      shift
      ;;
    -u)
      _PUSH="1"
      shift
      _PUSH_ARGS+=" ${1}"
      shift
      ;;
    -P)
      if [[ -n ${_USE_BRANCH} ]]; then
        echo "'-P' conflicts with '-b'" >&2
        exit 1
      fi
      shift
      _AUTOGEN=1
      ;;
    -v)
      shift
      _VERBOSE=1
      ;;
    --)
      shift
      break
      ;;
  esac
done

_MOD_DIR="${1}"
_VERSION="${2}"

_O_REDIRECT="/dev/null"
if [[ -n ${_VERBOSE} ]]; then
  _O_REDIRECT="/dev/stdout"
fi

_do() {
  set -- "${@}"
  echo ">>>" "${@}"
  "${@}" >${_O_REDIRECT}
}

_is_in_mod() {
  if ! go list >${_O_REDIRECT}; then
    echo "'${_MOD_DIR}' is not a module folder." >&2
    exit 1
  fi

  _MOD_DIR=$(go list -f '{{.GoMod}}' -m)
  _MOD_DIR=$(realpath ${_MOD_DIR%/go.mod})

  if [[ "$(go list -f '{{.Main}}' -m)" != true ]]; then
    echo "'${_MOD_DIR}' contains a non-main module." >&2
    exit 1
  fi
  return 0
}

_base_mod_path() {
  local _mod_path
  _mod_path=$(go list -f '{{.Path}}' -m)
  if [[ ${_mod_path##*/} =~ ^v[[:digit:]] ]]; then
    _mod_path=${_mod_path%/*}
  fi
  echo ${_mod_path##*/}
}

_is_dir() {
  if [[ -d "${1}" ]]; then
    return 0
  else
    echo "'${1}' is not a directory, abort." >&2
    exit 1
  fi
}

# for git only
# $1: git repo path
_is_vcs() {
  if [[ -z ${_VERSION} && -z ${_USE_BRANCH} ]]; then
    # ignore this check when _VERSION and _USE_BRANCH are all unset
    return 0
  fi
  if git -C "${1}" status &>/dev/null; then
    return 0
  else
    echo "Please manually do \`git init '${1}'\` first" >&2
    exit 1
  fi
}

[[ -z ${_MOD_DIR} ]] || _do pushd "${_MOD_DIR}"
_is_in_mod

if [[ -z ${_VCS_DIR} || \
  ${_VCS_DIR#${_MOD_DIR}} != ${_VCS_DIR} || \
  ${_MOD_DIR#${_VCS_DIR}} != ${_MOD_DIR} ]]; then
  if [[ -n ${_VCS_DIR} ]]; then
    echo "the specified VCS dir is intersected with PKG dir, do as VCS path omitted" >&2
  fi
  unset _VCS_DIR _AUTOGEN _VERSION _USE_BRANCH _PUSH
else
  _is_dir "${_VCS_DIR}"
fi

# prepare VCS path or branch name
if [[ -n ${_AUTOGEN} ]]; then
  _VCS_DIR="${_VCS_DIR%/}/vendor-$(_base_mod_path)"
  [[ -d "${_VCS_DIR}" ]] || _do mkdir -p "${_VCS_DIR}"
elif [[ -n ${_USE_BRANCH} ]]; then
  _BRANCH_NAME=${_BRANCH_NAME:-$(_base_mod_path)}
fi

_is_vcs "${_VCS_DIR}"
# prepare push args
_REMOTE_REPO=
_REMOTE_REF=
if [[ -n ${_PUSH} ]]; then
  set -- ${_PUSH_ARGS}
  _PUSH_ARGS=''
  while :; do
    case ${1} in
      -o)
        _PUSH_ARGS+=" ${1}"
        shift
        _PUSH_ARGS+=" ${1}"
        ;;
      -*)
        _PUSH_ARGS+=" ${1}"
        ;;
      *)
        if [[ -z ${_REMOTE_REPO} ]]; then
          _REMOTE_REPO=${1}
        elif [[ -n ${1} ]]; then
          _REMOTE_REF=${1}
        fi
        ;;
    esac
    shift || break
  done
  if [[ -z ${_REMOTE_REPO} ]]; then
    git -C "${_VCS_DIR}" config branch.${_BRANCH_NAME}.remote >${_O_REDIRECT} || \
      {
        echo "neigher specified remote for branch '${_BRANCH_NAME}', nor default upstream branch" >&2
        echo "skip push action!"
        unset _PUSH
      }
  fi
fi

_VENDOR="${_VCS_DIR%/}${_VCS_DIR:+/}vendor"

# overview
echo "will"
if [[ -n ${_USE_BRANCH} ]]; then
  echo " 0. checkout the branch '${_BRANCH_NAME}' of '${_VCS_DIR}',"
  echo "    if '${_BRANCH_NAME}' non exists, it will be created in orphan mode,"
  echo "    and all previous contents will be removed"
fi
echo " 1. remove '${_VENDOR}' directory
 2. re-generate it"
if [[ -n ${_VERSION} ]]; then
  echo " 3. make/update tag with version '${_VERSION}'"
  if [[ -n ${_PUSH} ]]; then
    echo " 4. push with args '${_PUSH_ARGS# } ${_REMOTE_REPO} ${_REMOTE_REF}'"
  fi
fi
if [[ -n ${_USE_BRANCH} ]]; then
  echo " 5. checkout back to the previous branch if exists"
fi
echo
_WAIT=3
echo -en "Starting in: \033[33m\033[1m"
while [[ ${_WAIT} -gt 0 ]]; do
  echo -en "${_WAIT} "
  _WAIT=$((${_WAIT} -  1))
  sleep 1
done
echo -e "\033[0m"

# main jobs
## check branch
if [[ -n ${_USE_BRANCH} ]]; then
  _do pushd "${_VCS_DIR}"
  _BRANCH_OLD=$(git branch --show-current)
  trap '
  if [[ ! "$(git branch --list ${_BRANCH_OLD})" =~ ^\*|^$ ]]; then
    _do git checkout ${_BRANCH_OLD}
  fi
  if [[ "$(git stash list)" != "" ]]; then
    _do git stash pop
  fi
  ' EXIT
  _do git stash push || true
  if [[ $(git branch --list ${_BRANCH_NAME}) == '' ]]; then
    _do git checkout --orphan ${_BRANCH_NAME}
    _do git rm -rf . || true
  else
    _do git checkout ${_BRANCH_NAME}
  fi
  _do popd
fi

# mod actions
_do go mod verify
_do go mod tidy ${_VERBOSE:+-v} ${_GO_VER:+-go} ${_GO_VER}

[[ ! -d ${_VENDOR} ]] || _do rm -rf ${_VENDOR}
_do go mod vendor ${_VERBOSE:+-v} ${_VCS_DIR:+-o} ${_VCS_DIR:+${_VENDOR}}

[[ -n ${_VERSION} ]] || exit 0

_do pushd "${_VCS_DIR}"
_do git add ./vendor
if [[ $(git log --oneline ./vendor 2>/dev/null | wc -l | cut -d' ' -f1) == 0 ]]; then
  _commit_msg_prefix="add"
else
  _commit_msg_prefix="update"
fi
if [[ $(git diff --cached ./vendor) == '' ]]; then
  echo "no changed, skip git commit and following actions."
  exit 1
fi
_do git commit -m "vendor: ${_commit_msg_prefix} ${_VERSION}"
if [[ -n ${_BRANCH_NAME} ]]; then
  _VERSION="vendor-${_BRANCH_NAME}-${_VERSION}"
else
  _VERSION="v${_VERSION#v}"
fi
if [[ $(git tag --list ${_VERSION}) != '' ]]; then
  _do git tag -d "${_VERSION}"
fi
_do git tag -a "${_VERSION}" -m "${_VERSION}"

[[ -n ${_PUSH} ]] || exit 0

_do git push ${_PUSH_ARGS} ${_REMOTE_REPO} ${_REMOTE_REF}
