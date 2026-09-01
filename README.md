# ChatGPT Desktop for Manjaro KDE

This repository contains only the packaging layer for a Manjaro KDE x86_64
package. It downloads the official OpenAI Linux `chatgpt_amd64.deb`, extracts
its data archive with `dpkg-deb -x`, and repackages that unchanged runtime as a
pacman package.

No third-party application source, patches, or updater is used. Debian
maintainer scripts are not executed, so installing this package does not add an
APT repository.

## Build locally

On Manjaro/Arch:

```bash
sudo pacman -S --needed base-devel ca-certificates curl dpkg jq
./scripts/build-manjaro.sh
sudo pacman -U dist/codex-desktop-*.pkg.zst
```

The output is x86_64-only and uses the exact version reported by the current
official `.deb`. Override `CHATGPT_DEB_URL` only when deliberately testing a
different official package.

The installed KDE desktop entry sets `GTK_IM_MODULE=fcitx` and
`XMODIFIERS=@im=fcitx`, which keeps Fcitx5 Rime/Wubi input working in the
XWayland launch path. Install `fcitx5` and `fcitx5-rime` separately when needed.

## Releases

GitHub Actions builds only Manjaro KDE x86_64 and publishes one `.pkg.zst`
package, its SHA-256 file, and build metadata for each upstream version.

The upstream ChatGPT application and its trademarks remain the property of
OpenAI. This repository provides packaging scripts only.
