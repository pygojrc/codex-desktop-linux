# ChatGPT Desktop for Manjaro KDE

This repository contains only the packaging layer for a Manjaro KDE x86_64
package. It downloads the official OpenAI Linux `chatgpt_amd64.deb`,
extracts its data archive with `dpkg-deb -x`, and repackages the upstream
runtime as a pacman package.

The standard release track uses no third-party application source,
application-internal patches, or updater. Debian maintainer scripts are not
executed, so installing this package does not add an APT repository. A separate
historical Model Picker Presets build is described below.

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

The output is x86_64-only and uses the exact version reported by the downloaded
official `.deb`. Override `CHATGPT_DEB_URL` only when deliberately testing a
different official package. CI also passes the SHA-256 and expected upstream
version from OpenAI's APT package index so the downloaded input is verified
before packaging.

The one-command installer downloads the latest Release asset, checks its
SHA-256 checksum, and installs it with `pacman`:

```bash
curl -fsSL https://raw.githubusercontent.com/pygojrc/codex-desktop-linux/main/install.sh | sh
```

Install `fcitx5` and `fcitx5-rime` separately when Wubi/Rime input support is
needed.

## Releases

GitHub Actions checks OpenAI's official APT `Packages` index every 30 minutes.
The check only downloads the small package index. When a new upstream version
does not already have a matching GitHub Release, the workflow downloads the
versioned `.deb` from the index, verifies its SHA-256, builds the Manjaro KDE
x86_64 package, and publishes one `.pkg.zst`, its SHA-256 file, and build
metadata.

The upstream ChatGPT application and its trademarks remain the property of
OpenAI. This repository provides packaging scripts only.

## Historical 26.928.40906 Model Picker Presets build

The independent `release-mpp.yml` workflow supports manual dispatch and push
events on two dedicated branches. It uses the pinned
`manjaro-kde-26.928.40906` Release asset and the ilysenko Git submodule at
`a0b23fed42be7f03d5a23f017efb111b1346a559`. Only
`model-picker-default-presets` is enabled. The five feature descriptors patch
three ASAR webview assets; the script rejects missing or unexpected changes.
The ordinary scheduled release and installer remain on the original track.

Edit `configs/mpp/features.json` before building to choose ordered model and
effort pairs. Exactly one pair must have `"default": true`. These values are
compiled into the ASAR; changing them requires a rebuild and a new release
suffix. The sample pairs do not grant model access and may be filtered by the
account catalog or workspace policy.

To build locally on Arch/Manjaro, initialize the submodule, provide the
historical asset, install the pinned ASAR CLI, and run:

```bash
git submodule update --init --recursive
npm install --prefix .mpp-tooling --no-save @electron/asar@4.3.1
MPP_SOURCE_PACKAGE=/path/to/codex-desktop-26.928.40906-1-x86_64.pkg.zst \
  MPP_ASAR_BIN="$PWD/.mpp-tooling/node_modules/.bin/asar" \
  ./scripts/build-mpp.sh
```

The build checks the pinned source SHA-256, ASAR layout, each descriptor,
the changed asset set, package metadata, Fcitx5 wrapper, bundled CLI and
code-mode host. `dist/` contains the standard `.pkg.tar.zst`, checksum,
patch report and provenance metadata. Push to `ci/mpp-26.928.40906` for a
build-only Artifact, or push to `release/mpp-26.928.40906` to build, verify,
and create an independent prerelease tag. Manual dispatch still accepts
`publish=false` or `publish=true`. Desktop login, Quick Chat and model picker
behavior still require testing in Manjaro KDE.
