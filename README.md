# xtensa-lx106-elf toolchain

Builds of the ESP8266 compiler, GCC 10.3 for `xtensa-lx106-elf`, for the host
systems ESPHome supports:

| System | Built on |
|---|---|
| `linux_x86_64` | Linux x86_64, in an Ubuntu 20.04 image |
| `linux_aarch64` | Linux arm64, in an Ubuntu 20.04 image |
| `darwin_arm64` | macOS arm64 |
| `darwin_x86_64` | macOS x86_64 |
| `windows_amd64` | Linux x86_64 with mingw-w64 |

The compiler generates the same code as the `toolchain-xtensa 2.100300.220621`
package from the PlatformIO registry. The reason for this repository is that
no build of that package runs on arm64 macOS without Rosetta 2.

## How it is built

1. `ci/prepare-sources.sh` fetches every source at a fixed commit or checksum
   and applies the patches. All hosts build from this one tree.
2. `ci/build.sh <system> host` builds binutils and GCC, the programs that run
   on the host.
3. `ci/build.sh linux_x86_64 device` builds newlib, libgcc, libstdc++ and the
   hal library, the code that ends up in firmware. This happens once, and
   every package gets the same copy.
4. `ci/package.sh <system>` combines the two into an archive.
5. `ci/verify.sh` compiles and links the sources in `tests/` and writes a
   checksum for every output. Each host must produce the same checksums as the
   registry package.
6. `ci/compare-device.sh` compares the device libraries and headers with the
   registry package.

## Fixed versions

| Source | Version |
|---|---|
| GCC | 10.3.0, commit `f00b5710` |
| binutils | 2.32, commit `a9d9a104` |
| newlib | [earlephilhower/newlib-xtensa](https://github.com/earlephilhower/newlib-xtensa) commit `d6e3fcdb` |
| hal | [earlephilhower/lx106-hal](https://github.com/earlephilhower/lx106-hal) commit `e4bcc63c` |
| gmp, mpfr, mpc, isl | 6.1.0, 3.1.4, 1.0.3, 0.18 |

The hal library is built with `mawk`. Its build splits some sources into one
object per function using a pattern only GNU awk understands; the registry
package was built with `mawk`, which skips the split.

The newlib commit is not the newest one. It is the one the libraries and
headers of the registry package match; a newer commit changes 15 objects in
libc and the `sys/pgmspace.h` header.

## Changes from the registry package

Two newlib changes save about 400 bytes of RAM on ESP8266; everything else matches the registry package.

| Change | Symbol | RAM |
|---|---|---|
| `--enable-newlib-global-atexit` moves the 32 entry atexit table out of the reent struct, into an object nothing links | `impure_data` | 240 to 96 B |
| `patches/newlib/newlib-locale-c-only-buffers.patch` sizes the locale name buffers for the `"C"` and `"ASCII"` that a build without `_MB_CAPABLE` stores | `__global_locale` | 364 to 104 B |

ESPHome's ESP8266 builds take libc and its headers from this toolchain; the Arduino core (3.1.2) ships no newlib headers, and its `libc_orig.a` is not linked. The prebuilt libraries in the Arduino core only reach the reent struct for `stdin`, `stdout` and `stderr`, which keep their offsets.

## Releases

Pushing a tag builds every host and publishes the archives with their
checksums as a release. A tag that contains `rc` becomes a prerelease.

## License

The build scripts, workflow and tests are licensed under the Apache License
2.0, see `LICENSE`. The patches in `patches/` and the toolchain archives are
covered by the licenses of the projects they belong to, mainly the GNU General
Public License version 3 or later for GCC and binutils; see
`patches/gcc/README.md`.
