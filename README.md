# ChatGPT Desktop for Manjaro KDE

This repository contains only the packaging layer for a Manjaro KDE x86_64
package. It downloads the latest official OpenAI Linux `chatgpt_amd64.deb`,
extracts its data archive with `dpkg-deb -x`, and repackages the upstream
runtime as a pacman package.

No third-party application source, application-internal patches, or updater is
used. Debian maintainer scripts are not executed, so installing this package
does not add an APT repository.

The only runtime compatibility change is the launcher environment needed for
KDE/Fcitx5 Wubi input: `/usr/bin/chatgpt` is replaced with a small wrapper that
sets `GTK_IM_MODULE=fcitx` and `XMODIFIERS=@im=fcitx`, then starts the official
`/usr/lib/chatgpt/codex-launcher`.

## Build locally

On Manjaro/Arch:

```bash
sudo pacman -S --needed base-devel ca-certificates curl dpkg
./scripts/build-manjaro.sh
sudo pacman -U dist/codex-desktop-*.pkg.zst
```

The output is x86_64-only and uses the exact version reported by the current
official `.deb`. Override `CHATGPT_DEB_URL` only when deliberately testing a
different official package.

The one-command installer downloads the latest Release asset, checks its
SHA-256 checksum, and installs it with `pacman`:

```bash
curl -fsSL https://raw.githubusercontent.com/pygojrc/codex-desktop-linux/main/install.sh | sh
```

Install `fcitx5` and `fcitx5-rime` separately when Wubi/Rime input support is
needed.

## Releases

GitHub Actions builds only Manjaro KDE x86_64 and publishes one `.pkg.zst`
package, its SHA-256 file, and build metadata for each upstream version.

The upstream ChatGPT application and its trademarks remain the property of
OpenAI. This repository provides packaging scripts only.
