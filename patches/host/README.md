# Host patches

Patches that let GCC 10.3 build and run on a host system. They must not
change the code the compiler generates.

- `gcc-host-aarch64-darwin.patch`: GCC 10 does not know arm64 macOS as a host.
  This adds the host entry and hook file, mirroring the x86 macOS ones.

- `gcc-safe-ctype-macos.patch`: the C++ library headers of current macOS use
  the ctype names that GCC poisons for its own code. This leaves out the
  poisoning on macOS hosts.

These patches modify GCC and are covered by GCC's license, the GNU General
Public License version 3 or later.
