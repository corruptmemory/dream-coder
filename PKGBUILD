# Maintainer: Jim Powers <jim@corruptmemory.com>
#
# Repackages DreamCoder's official Debian package for Arch Linux.
# Version bumps come from ./update.sh; see README.md for the trust model.
#
# Only the .deb's file payload (data.tar.xz) is used. Its maintainer scripts
# are Hydraulic Conveyor boilerplate: they name no systemd services, so all
# they do is refresh the desktop, icon and MIME caches, which pacman's own
# hooks already do. Its /etc/apt files register an apt source and signing key
# that have no meaning on Arch, so they are left out.

pkgname=dreamcoder-local
_debname=dreamcoder-dreamcoder
pkgver=1.0.15
pkgrel=1
pkgdesc="AI-powered coding assistant with semantic code search (repack of the official .deb)"
arch=('x86_64')
url="https://www.dreamcoder.ai/"
license=('LicenseRef-Proprietary')

# The .deb's "Depends:" field, in Arch names: libc6 (glibc),
# libgcc-s1 (libgcc), libgomp1 (libgomp), libstdc++6 (libstdc++) and
# zlib1g (zlib). These are also the only libraries the shipped ELF files
# need from the system; everything else (Python 3.12, OpenSSL, SQLite,
# llama.cpp, ONNX Runtime) is bundled under /usr/lib/dreamcoder.
depends=('glibc'
         'hicolor-icon-theme'
         'libgcc'
         'libgomp'
         'libstdc++'
         'zlib')

# The server opens the web UI with Python's webbrowser module, which
# uses xdg-open. git is what the coding agent works with.
optdepends=('xdg-utils: open the web UI in the default browser'
            'git: version control for the projects DreamCoder works on')

provides=('dreamcoder')
conflicts=('dreamcoder' 'dreamcoder-bin')

# Prebuilt binaries: the Nuitka-compiled server and its bundled libraries
# are already stripped, and stripping vendor payloads gains nothing.
# !debug disables the -debug split package, which only makes sense when
# compiling from source.
options=('!strip' '!debug')

source=("https://www.dreamcoder.ai/downloads/files/public/${pkgver}/linux-deb/debian/${_debname}_${pkgver}_amd64.deb")
sha256sums=('5e94aaa8e6bbf3d75d75e688fe208e992c00602a896f2c5608b7060a2acc5efd')

package() {
  # makepkg unpacks the .deb (an ar archive) into $srcdir: debian-binary,
  # control.tar.xz (metadata and maintainer scripts, unused) and
  # data.tar.xz, the file payload.
  tar -xf data.tar.xz -C "$pkgdir"

  # apt source and key for a Debian repository: nothing on Arch reads them.
  rm -r "$pkgdir/etc"

  # Upstream's /usr/bin/dreamcoder is an absolute symlink; make it relative
  # so the package tree is self-consistent.
  ln -sfn ../lib/dreamcoder/dreamcoder/dreamcoder-server "$pkgdir/usr/bin/dreamcoder"
}
