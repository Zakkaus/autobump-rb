# Copyright 2026 Gentoo Authors
EAPI=8
DESCRIPTION="patched fixture"
SRC_URI="https://example.invalid/${P}.tar.gz"
KEYWORDS="~amd64"
src_prepare() { eapply "${FILESDIR}"/fix.patch; default; }
