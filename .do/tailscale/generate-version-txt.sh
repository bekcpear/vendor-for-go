#!/usr/bin/env bash
#

if [[ ! -d "$VCS_DIR" ]]; then
  echo "no VCS_DIR! exit generating version.txt"
  exit 0
fi

set -x
__TMPDIR=$(mktemp -d)
pushd $__TMPDIR
trap "
popd || true
rm -rf $__TMPDIR
" EXIT

set -e

[[ $VERSION =~ ^v ]] || VERSION="v$VERSION"
git clone --branch=$VERSION --depth=1 https://github.com/tailscale/tailscale.git
cd tailscale
./build_dist.sh shellvars >"${VCS_DIR%%/}/version.txt"
cd "$VCS_DIR"
git add version.txt
git commit -m "version.txt: update for $VERSION"
