### vendor tarball maker for go module

It assists with Gentoo Portage packaging for go packages,
refer to: https://github.com/bekcpear/ryans-repos/issues/4

  run `./gen.sh -h` for help.

I wrote a new eclass [go.eclass](https://github.com/bekcpear/ryans-repos/blob/main/eclass/go.eclass) to
build go packages more convenient.

Just inherit that eclass and add tarball URL to the `SRC_URI` variable.
   e.g.:
   ```bash
   inherit go

   ...

   SRC_URI="...
     https://github.com/xxx/xxx-vendor/archive/refs/tags/v${PV}.tar.gz -> ${P}-vendor.tar.gz"
   ```

Refer to the comments within that eclass for more information.
