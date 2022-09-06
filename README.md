### vendor tarball maker for go module

It assists with Gentoo Portage packaging for go packages,
refer to: https://github.com/bekcpear/ryans-repos/issues/4

  run `./gen.sh -h` for help.

Due to the vendor-tarball is not supported by official go-module.eclass,
here are 3 extra works need to do by yourself.

1. add tarball URL to the `SRC_URI` variable.
   e.g.:
   ```bash
   SRC_URI="...
     https://github.com/xxx/xxx-vendor/archive/refs/tags/v${PV}.tar.gz -> ${P}-vendor.tar.gz"
   ```
2. mv `vendor` dir to `${S}` path.
   e.g.:
   ```bash
   src_prepare() {
     mv ../${PN}-vendor-${PV}/* ./ || die
     # Due to this script always make a go mod tidy,
     # if the pkg not make a go mod tidy when it is packaged,
     # a conflict occurs.
     # For a tidy package, the go-mod-sum.diff file should be empty.
     eapply go-mod-sum.diff
     default
   }
   ```
3. add the `-mod vendor` argument to `go` cmd when build/install, to skip download modules from network.
   e.g.:
   ```bash
   ego -mod vendor ...
   ```
