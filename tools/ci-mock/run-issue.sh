#!/bin/bash
# Runs INSIDE the autobump-ci:ready container. Reproduces autobump.yml steps 4-8 for
# ONE bump, then runs the engine with --install (a REAL emerge, deps via getbinpkg)
# but WITHOUT --pr, so nothing is pushed and no PR is opened -- a dry-run that shows
# the true CI build result (clean gentoo container + latest binpkg tools), which the
# dev box cannot: its go/deps/installed set differ from a clean CI container.
#
# Mounts expected: /autobump-rb (ro, the engine), /host-overlay (ro, clone source).
# Usage: run-issue.sh <cat/pkg> <newver>
set -uo pipefail
ARGS="$*"
echo "==================== CI-mock: $ARGS ===================="

echo "### clone overlay into an independent writable checkout"
# the host-mounted repo is owned by the host uid, not container root -> git refuses it
git config --global --add safe.directory '*'
rm -rf /work/overlay; mkdir -p /work
# --depth 1 so we copy only the tip, not the whole overlay .git history (hundreds of MB);
# --branch master so the checkout lands on master (host HEAD may be a bump branch).
git clone --quiet --depth 1 --branch master /host-overlay /work/overlay
cd /work/overlay

echo "### register repos.conf (identical to autobump.yml step 'register overlay')"
mkdir -p /etc/portage/repos.conf
cat > /etc/portage/repos.conf/gentoo.conf << EOF
[DEFAULT]
main-repo = gentoo

[gentoo]
location = $(portageq get_repo_path / gentoo)
EOF
cat > /etc/portage/repos.conf/repo.conf << EOF
[$(cat profiles/repo_name)]
location = $(realpath .)
priority = 0
EOF
git config --global --add safe.directory "$(realpath .)"
git config user.name gentoo-zh-bot
git config user.email bot@gentoozh.org
# overlay packages carry many non-@FREE licenses (FSL-1.1-MIT, Anthropic, etc); without
# this every such bump license-masks and defers. autobump.yml needs the same on deploy.
echo 'ACCEPT_LICENSE="*"' >> /etc/portage/make.conf

echo "### engine --install (real emerge via getbinpkg; NO --pr, dry-run)"
# sync master from the local origin (the host clone, already up to date) instead of
# fetching gentoo-zh/overlay over the network -- faster, self-contained.
AUTOBUMP_REPO="$(realpath .)" AUTOBUMP_LIVE_OVERLAY="$(realpath .)" AUTOBUMP_SYNC_REMOTE=origin \
  ruby /autobump-rb/bin/autobump "$@" --install
rc=$?
echo "### engine exit=$rc"
# if an /out dir is mounted and a bump commit was made, export it as a patch so the host
# can apply it and open a PR -- container speed (getbinpkg), no local emerge, no --rm loss.
if [ "$rc" = 0 ] && [ -d /out ]; then
  git format-patch -1 -o /out >/dev/null 2>&1 && echo "### exported commit patch to /out"
fi
exit $rc
