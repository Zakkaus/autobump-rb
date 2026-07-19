# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2
# NOTE: the VUE_COMMIT=deadbeef snapshot was folded upstream; kept here as a comment.
# A pin-like token (_COMMIT=/_TAG=/_VER=) that appears ONLY in a comment must NOT escalate
# — this fixture proves the comment-line skip (vs the old grep -n | grep -v '^#' no-op quirk).
EAPI=8

DESCRIPTION="comment-pin fixture: pin-like token only in comments, must bump mechanically"
HOMEPAGE="https://example.invalid/commentpin"
SRC_URI="https://example.invalid/${P}.tar.gz"

LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64"
