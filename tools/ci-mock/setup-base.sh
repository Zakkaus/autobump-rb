#!/bin/bash
# Runs INSIDE a gentoo/stage3:amd64-desktop-openrc container to reproduce the CI
# environment of .github/workflows/autobump.yml steps 1-3 (sync + portage + tooling).
# Commit the result to an image (autobump-ci:ready) so per-issue test runs skip this.
set -euo pipefail

echo "### 1/3 emerge-webrsync (sync gentoo main tree)"
emerge-webrsync

echo "### 2/3 setup portage (getbinpkg + MAKEOPTS + elog), identical to autobump.yml"
{
  echo 'FEATURES="${FEATURES} getbinpkg"'
  echo "MAKEOPTS=\"\${MAKEOPTS} -j$(nproc)\""
  echo 'PORTAGE_ELOG_CLASSES="qa warn error"'
  echo 'PORTAGE_ELOG_SYSTEM="save"'
} >> /etc/portage/make.conf
getuto
install -dm775 -o root -g portage /var/cache/distfiles

echo "### 3/3 install tooling via getbinpkg (ruby engine + pkgdev/pkgcheck + qlist/qa-vdb)"
# xorg-server/xvfb skipped here (GUI launch probe just skips) to keep the base small;
# add it back if a GUI package needs the probe.
emerge --quiet --getbinpkg --autounmask=y --autounmask-write=y --autounmask-continue=y \
  dev-lang/ruby dev-vcs/git dev-util/pkgdev dev-util/pkgcheck app-portage/portage-utils \
  app-portage/iwdevtools dev-util/github-cli app-misc/jq

echo "### base ready: ruby=$(ruby -v 2>/dev/null | cut -d' ' -f2) pkgdev=$(pkgdev --version 2>/dev/null)"
