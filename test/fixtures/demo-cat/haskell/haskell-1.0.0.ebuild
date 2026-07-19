# Copyright 2026 Gentoo Authors
# hackport/haskell-cabal fixture: a version-only bump must escalate (dep bounds come
# from the upstream .cabal, not the ebuild).
EAPI=8
inherit haskell-cabal
DESCRIPTION="haskell-cabal fixture"
SRC_URI="https://example.invalid/${P}.tar.gz"
KEYWORDS="~amd64"
