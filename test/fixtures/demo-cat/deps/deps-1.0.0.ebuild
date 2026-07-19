# Copyright 2026 Gentoo Authors
EAPI=8
DESCRIPTION="deps-artifact fixture"
SRC_URI="
	https://example.invalid/${P}.tar.gz
	https://github.com/gentoo-zh-drafts/deps/releases/download/v${PV}/${P}-vendor.tar.xz
"
KEYWORDS="~amd64"
