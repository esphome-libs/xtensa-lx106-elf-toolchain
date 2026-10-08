# Compiler patches

These patches change GCC 10.3 for the ESP8266. They decide what code the
compiler generates, so they are applied unchanged and in file name order.

## Origin

The files are copied without changes from
[earlephilhower/esp-quick-toolchain](https://github.com/earlephilhower/esp-quick-toolchain)
at commit `e5f9fec`, the commit the `toolchain-xtensa 2.100300.220621` package
was built from:

- `gcc-001-jump-tables-in-text-section-earlephilhower.patch` from `patches/`
- all other files from `patches/gcc10.3/`

Many of them are commits from GCC itself or from
[jcmvbkbc/gcc-xtensa](https://github.com/jcmvbkbc/gcc-xtensa); those name their
author in the patch header.

## Local patches

These are not from esp-quick-toolchain; keep them when re-syncing from there.

- `gcc-template-section-attribute.patch`: backport of GCC commit
  `ea7bebff7cc5` (PR c++/70435, GCC 14) so section attributes reach template
  instantiations

## License

The patches modify GCC and are covered by GCC's license, the GNU General
Public License version 3 or later. Patches to `libgcc` and `libstdc++-v3` also
carry the GCC Runtime Library Exception. They are not covered by the Apache
License that applies to the build scripts in this repository.
