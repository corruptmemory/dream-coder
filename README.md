# dreamcoder-local

An Arch Linux package for [DreamCoder](https://www.dreamcoder.ai/), built from the
vendor's official Debian package. This repository holds only the build recipe; the
software itself is proprietary and is downloaded from dreamcoder.ai at build time.
It is not affiliated with DreamCoder.

## Install

```sh
git clone https://github.com/corruptmemory/dream-coder.git
cd dream-coder
makepkg -si
```

Then run `dreamcoder`, or open DreamCoder from the application menu, and go to
<http://localhost:9889>. Sign in with a DreamCoder account on first launch.

## Update

```sh
./update.sh        # finds the newest release and pins its hash
makepkg -si
git commit -am "dreamcoder <version>"
```

`./update.sh --check` reports without changing anything. `--force` re-pins the
current version.

## Trust model

DreamCoder publishes no checksum or signature for its `.deb`. The vendor's installer,
<https://www.dreamcoder.ai/install.sh>, downloads the package over HTTPS and hands it
to `apt-get`; nothing else checks it. `update.sh` does the same and goes a little
further:

- It takes the download URL from that installer, so it follows whatever the vendor
  currently ships.
- It checks the package name, architecture and version in the `.deb`'s control file.
- It pins the `.deb`'s SHA-256 in `PKGBUILD`, so any later build of that version
  fails if the file on the server changes.
- It flags changes that need the recipe reviewed: payload files outside `usr/`, a
  maintainer script that starts a systemd service, or a changed `Depends:` field.

The `.deb` also installs an apt source (`https://dreamcoder.ai/releases/update/linux/`,
suite `debian/`) and its signing key, fingerprint
`E09B F2B8 BD0F 3165 B2CD 9DFC A002 A900 3AF7 F769`. That repository returned 404 for
every index file on 2026-11-20. If it is ever published, its signed index would allow
`update.sh` to verify the `.deb` against the vendor's key.

## Differences from the .deb

- Only the file payload is installed. The maintainer scripts are Hydraulic Conveyor
  boilerplate that name no services; they only refresh desktop, icon and MIME caches,
  which pacman's hooks already do.
- `/etc/apt/` (the apt source and key above) is left out; nothing on Arch reads it.
- `/usr/bin/dreamcoder` is a relative symlink to
  `/usr/lib/dreamcoder/dreamcoder/dreamcoder-server`.

## Notes

- The server is a Nuitka build with its own Python 3.12, OpenSSL, SQLite, llama.cpp
  and ONNX Runtime. From the system it needs only glibc, libgcc, libstdc++, libgomp
  and zlib.
- It binds to `127.0.0.1:9889` by default; `dreamcoder --help` lists the options.
- Data lives in `~/.local/share/dreamcoder` and `~/.local/state/dreamcoder`.
  `pacman -R dreamcoder-local` leaves them in place.
- No self-updater was found in the 1.0.15 build; new versions come through this recipe.
