### vendor tarball maker for go module

It assists with Gentoo Portage packaging for go packages,
refer to: https://github.com/bekcpear/ryans-repos/issues/4

  run `./gen.sh -h` for help.

Due to the vendor-tarball is not supported by official go-module.eclass,
you need do two extra works by yourself.

1. mv `vendor` dir to `${S}` path.
   e.g.:
   ```bash
   src_prepare() {
     mv ../${PN}-vendor-${PV}/vendor ./ || die
     default
   }
   ```
2. add the `-mod vendor` argument to `go` cmd when build/install, to skip download modules from network.
   e.g.:
   ```bash
   ego -mod vendor ...
   ```
