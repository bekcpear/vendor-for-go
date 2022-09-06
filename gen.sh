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
    -u[<args>]        Auto push to upstream with optional <args> (quote them)
    -x  <path>        Exec an extra script after vendor generated, before commit 'vendor'
                       MOD_DIR: exported var for PKG dir
                       VCS_DIR: exported var for VCS dir
                       can be specified multiple times
                       You need to commit files other than 'vendor' folder in this script
    -y                The following script specified by '-x' will be executed before vendor generated
    -z[<tool>]        Make a tarball instead of VCS tag,
                       the default compression tool is 'xz', you can also specify one
                       [bzip2,gzip,xz,zstd,others?]
    -g  <ver>         Update the go directive to the indicated version
    -v                Verbose output

  Examples:
    # the simplest way to just generate the vendor dir under the current path
    ./gen.sh

    # 1. specify the './pkgpath' is the module dir
    # 2. checkout branch with the basepath of the module path of current dir
    # 3. generate vendor dir to '/path/to/vcs/vendor'
    # 4. commit and make tag with version 1.0.0
    ./gen.sh -b -p /path/to/vcs ./pkgpath 1.0.0
"
}

set +e
unset GETOPT_COMPATIBLE
getopt -T
if [[ ${?} != 4 ]]; then
  echo "The command 'getopt' of Linux version is necessory to parse parameters." >&2
  exit 1
fi
_ARGS=$(getopt -o 'g:p:x:u::b::z::Pyv' -- "$@")
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
      ;;
    -p)
      shift
      if [[ ${1} == '' ]]; then
        echo "wrong value for '-p'" >&2
        exit 1
      fi
      _VCS_DIR="$(realpath ${1})"
      ;;
    -b)
      if [[ -n ${_AUTOGEN} ]]; then
        echo "'-b' conflicts with '-P'" >&2
        exit 1
      fi
      _USE_BRANCH=1
      shift
      _BRANCH_NAME="${1}"
      ;;
    -u)
      _PUSH="1"
      shift
      _PUSH_ARGS+=" ${1}"
      ;;
    -P)
      if [[ -n ${_USE_BRANCH} ]]; then
        echo "'-P' conflicts with '-b'" >&2
        exit 1
      fi
      _AUTOGEN=1
      ;;
    -x)
      shift
      if [[ ${1} == '' ]]; then
        echo "wrong value for '-x'" >&2
        exit 1
      fi
      if [[ -n ${_EARLY_SCRIPT} ]]; then
        unset _EARLY_SCRIPT
        _EXTRA_SCRIPT_EARLY+=("$(realpath ${1})")
      else
        _EXTRA_SCRIPT+=("$(realpath ${1})")
      fi
      ;;
    -y)
      _EARLY_SCRIPT=1
      ;;
    -z)
      shift
      _TARBALL=1
      _COMPRESSION=${1:-xz}
      ;;
    -v)
      _VERBOSE=1
      ;;
    --)
      shift
      break
      ;;
  esac
  shift
done

_MOD_DIR="${1}"
_VERSION="${2}"
[[ -z ${_VERSION} ]] || _VCS=1

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
  if [[ -z ${_VCS} && -z ${_USE_BRANCH} ]]; then
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
  unset _VCS_DIR _AUTOGEN _VCS _USE_BRANCH _PUSH _EXTRA_SCRIPT _EXTRA_SCRIPT_EARLY _TARBALL
else
  _is_dir "${_VCS_DIR}"
fi

if [[ -n ${_TARBALL} ]]; then
  unset _VCS _USE_BRANCH
fi

# prepare VCS path or branch name
if [[ -n ${_AUTOGEN} || -n ${_TARBALL} ]]; then
  _VCS_DIR="${_VCS_DIR%/}/$(_base_mod_path)-vendor"
  if [[ -n ${_TARBALL} && -n ${_VERSION} ]]; then
    _VCS_DIR="${_VCS_DIR}-${_VERSION}"
  fi
  [[ -d "${_VCS_DIR}" ]] || _do mkdir -p "${_VCS_DIR}"
elif [[ -n ${_USE_BRANCH} ]]; then
  _BRANCH_NAME=${_BRANCH_NAME:-$(_base_mod_path)}
fi

_is_vcs "${_VCS_DIR}"
# prepare push args
_REMOTE_REPO=
_PUSH_REF=
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
          _PUSH_REF=${1}
        fi
        ;;
    esac
    shift || break
  done
  if [[ -z ${_REMOTE_REPO} ]]; then
    git -C "${_VCS_DIR}" config branch.${_BRANCH_NAME}.remote >${_O_REDIRECT} || \
      {
        echo "neither specified remote for branch '${_BRANCH_NAME}', nor default upstream branch" >&2
        echo "skip push action!"
        unset _PUSH
      }
  fi
fi

_VENDOR="${_VCS_DIR%/}${_VCS_DIR:+/}vendor"

# overview
echo "will"
declare -i _ACT_IDX=1
if [[ -n ${_USE_BRANCH} ]]; then
  echo "  ${_ACT_IDX}. checkout the branch '${_BRANCH_NAME}' of '${_VCS_DIR}',"
  echo "     if '${_BRANCH_NAME}' non exists, it will be created in orphan mode,"
  echo "     and all previous contents will be removed"
  _ACT_IDX+=1
fi
echo "  ${_ACT_IDX}. remove '${_VENDOR}' directory"
_ACT_IDX+=1
if [[ -n ${_VCS} ]]; then
  if [[ -n ${_EXTRA_SCRIPT_EARLY} ]]; then
    echo "  ${_ACT_IDX}. run '${_EXTRA_SCRIPT_EARLY[@]}'"
    _ACT_IDX+=1
  fi
fi
echo "  ${_ACT_IDX}. do go mod tidy"
_ACT_IDX+=1
echo "  ${_ACT_IDX}. re-generate vendor"
_ACT_IDX+=1
echo "  ${_ACT_IDX}. make diff patch for go.mod and go.sum"
_ACT_IDX+=1
if [[ -n ${_TARBALL} ]]; then
  echo "  ${_ACT_IDX}. make a tarball and compress with '${_COMPRESSION}'"
  _ACT_IDX+=1
fi
if [[ -n ${_VCS} ]]; then
  if [[ -n ${_EXTRA_SCRIPT} ]]; then
    echo "  ${_ACT_IDX}. run '${_EXTRA_SCRIPT[@]}'"
    _ACT_IDX+=1
  fi
  echo "  ${_ACT_IDX}. make/update tag with version '${_VERSION}'"
  _ACT_IDX+=1
  if [[ -n ${_PUSH} ]]; then
    echo "  ${_ACT_IDX}. push with args '${_PUSH_ARGS# } ${_REMOTE_REPO} ${_PUSH_REF}'"
    _ACT_IDX+=1
  fi
fi
if [[ -n ${_USE_BRANCH} ]]; then
  echo "  ${_ACT_IDX}. checkout back to the previous branch if exists"
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
  if [[ ! ${_VCS_DIR#$(pwd -P)} =~ ^$|^/$ && ${_VCS_DIR} != "/" ]]; then
    _do pushd "${_VCS_DIR}"
  fi
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

_run_script() {
  echo ">>> run extra script '${1}' ..."
  if [[ ! -x "${1}" ]]; then
    _do chmod +x "${1}" || true
  fi
  (
  export MOD_DIR=${_MOD_DIR}
  export VCS_DIR=${_VCS_DIR}
  set +e
  "${1}"
  ) || true
  echo ">>> extra script '${1}' finished."
}

# $1: path related to repo path
# $2: repo path
_git_commit() {
  _do git ${2:+-C} ${2} add ${1}
  if [[ $(git ${2:+-C} ${2} log --oneline ${1} 2>/dev/null | wc -l | cut -d' ' -f1) == 0 ]]; then
    _commit_msg_prefix="add"
  else
    _commit_msg_prefix="update"
  fi
  if [[ $(git ${2:+-C} ${2} diff --cached ${1} | head -1) == '' ]]; then
    echo "'${1}' not changed, skip commit."
  else
    _do git ${2:+-C} ${2} commit -m "${1#./}: ${_commit_msg_prefix} ${_VERSION}"
  fi
}

# save original go.sum and go.mod
_TMPDIR=$(mktemp -d)
_do cp -a go.sum go.mod ${_TMPDIR}/
_do pushd ${_TMPDIR}
_do git init . 2>/dev/null
_do git add go.*
_do git commit -m test
_do popd

if [[ -n ${_EXTRA_SCRIPT_EARLY} ]]; then
  for _script in "${_EXTRA_SCRIPT_EARLY[@]}"; do
    _run_script "${_script}"
  done
fi

# mod actions
_do go mod verify
_do go mod tidy ${_VERBOSE:+-v} ${_GO_VER:+-go} ${_GO_VER}

[[ ! -d ${_VENDOR} ]] || _do rm -rf ${_VENDOR}
_do go mod vendor ${_VERBOSE:+-v} ${_VCS_DIR:+-o} ${_VCS_DIR:+${_VENDOR}}

# get go.sum and go.mod patch
_do cp -a go.sum go.mod ${_TMPDIR}/
git -C ${_TMPDIR} diff go.mod go.sum >${_VCS_DIR}${_VCS_DIR:+/}go-mod-sum.diff
[[ -n ${_VCS} ]] && \
  _git_commit ./go-mod-sum.diff ${_VCS_DIR}
_do rm -rf ${_TMPDIR}

if [[ -n ${_EXTRA_SCRIPT} ]]; then
  for _script in "${_EXTRA_SCRIPT[@]}"; do
    _run_script "${_script}"
  done
fi

if [[ -n ${_TARBALL} ]]; then
  _do pushd "${_VCS_DIR}/.."
  _do tar -cf "${_VCS_DIR##*/}.tar" "${_VCS_DIR##*/}"
  _do ${_COMPRESSION} "${_VCS_DIR##*/}.tar"
  _do rm -f "${_VCS_DIR}.tar"
  echo "here is your tarball:
    $(ls -1 ${_VCS_DIR}.tar.*)"
fi

[[ -n ${_VCS} ]] || exit 0

_do pushd "${_VCS_DIR}"
_git_commit ./vendor

if [[ -n ${_BRANCH_NAME} ]]; then
  _VERSION="vendor-${_BRANCH_NAME}-${_VERSION}"
else
  _VERSION="v${_VERSION#v}"
fi
if [[ $(git tag --list ${_VERSION}) != '' ]]; then
  if [[ $(git diff ${_VERSION}..HEAD | head -1) != '' || \
        $(git log ${_VERSION}..HEAD | head -1) != '' ]]; then
    _do git tag -d "${_VERSION}"
    _TAG_UPDATED=1
  else
    echo "Tag '${_VERSION}' exists, and no further updates, skip following actions."
    exit 1
  fi
fi
_do git tag -a "${_VERSION}" -m "${_VERSION}"

[[ -n ${_PUSH} ]] || exit 0

_do git push ${_PUSH_ARGS} ${_REMOTE_REPO} ${_PUSH_REF}
if [[ -n ${_TAG_UPDATED} ]]; then
  _do git push ${_PUSH_ARGS} --tags --force ${_REMOTE_REPO}
fi
