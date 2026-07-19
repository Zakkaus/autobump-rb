# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
# A _COMMIT=/_TAG= token that appears ONLY after an inline '#' must NOT escalate source_pin.
# The commentpin fixture covers a whole comment line; this one covers a token trailing live
# code on the same line, which source_pin must mask before scanning. There is no
# -deps/-vendor/-crates/node_modules bundle, so the inline-commented pin below is the only
# thing that could trip source_pin.
EAPI=8
DESCRIPTION="inline-commented pin must not escalate source_pin"
HOMEPAGE="https://example.invalid"
SRC_URI="https://example.invalid/${P}.tar.gz"  # dropped the old MY_COMMIT=deadbeef pin; plain tarball now
LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64"
