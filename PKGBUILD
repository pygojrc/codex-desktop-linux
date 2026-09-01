# Maintainer: pygojrc
pkgname=codex-desktop
pkgver=0.0.0
pkgrel=1
pkgdesc='ChatGPT desktop application for Manjaro KDE, repackaged from the official Linux .deb'
arch=('x86_64')
url='https://chatgpt.com/'
license=('custom:upstream')
depends=(
  'alsa-lib'
  'at-spi2-core'
  'cairo'
  'dbus'
  'expat'
  'gcc-libs'
  'gdk-pixbuf2'
  'glib2'
  'gtk3'
  'libcups'
  'libdrm'
  'libglvnd'
  'libnotify'
  'libx11'
  'libxcb'
  'libxcomposite'
  'libxdamage'
  'libxext'
  'libxfixes'
  'libxkbcommon'
  'libxrandr'
  'mesa'
  'nspr'
  'nss'
  'pango'
  'systemd-libs'
  'libusb'
  'xdg-utils'
  'xz'
)
optdepends=(
  'fcitx5: Chinese input method support'
  'fcitx5-rime: Rime Wubi input support'
  'git: project source control integration'
  'kde-cli-tools: opening files/trash on KDE'
  'pulseaudio: audio integration'
)
provides=('chatgpt')
conflicts=('chatgpt')
options=(!debug !strip)
source=()
sha256sums=()

package() {
  cp -a --no-preserve=ownership "${CODEX_STAGE_DIR}/." "${pkgdir}/"
}
