# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# e2e fixture: a package that REALLY emerges (no deps, trivial build), so the
# end-to-end test exercises stages 3-7 (branch/fetch/manifest/diff/emerge/elog/
# commit) against real portage -- hermetically, with a local distfile. The
# distfile is produced by test/e2e.sh, never committed.
EAPI=8

DESCRIPTION="autobump-rb e2e fixture: trivial package that really emerges"
HOMEPAGE="https://github.com/gentoo/gentoo"
# test/e2e.sh serves the distfile (and answers pkgcheck --net) from a local
# http server on 127.0.0.1:8199, so the whole run is hermetic and offline.
SRC_URI="http://127.0.0.1:8199/${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="mirror"

S="${WORKDIR}/${P}"

src_install() {
	dobin hello
}
