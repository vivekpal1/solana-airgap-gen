pkgname=solana-airgap-tools
pkgver=1.0
pkgrel=1
pkgdesc="Offline Solana wallet generator for airgapped systems"
arch=('x86_64')
license=('GPL3')
depends=('bash' 'coreutils')
source=('solana-airgap-gen.sh'
        'solana-offline.conf')
md5sums=('SKIP' 'SKIP')

package() {
  install -Dm755 "$srcdir/solana-airgap-gen.sh" "$pkgdir/usr/bin/solana-airgap-gen"
  install -Dm644 "$srcdir/solana-offline.conf" "$pkgdir/etc/solana-offline.conf"
}
