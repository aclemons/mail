#!/bin/bash

# Copyright 2024 Andrew Clemons, Tokyo Japan
# All rights reserved.
#
# Redistribution and use of this script, with or without modification, is
# permitted provided that the following conditions are met:
#
# 1. Redistributions of this script must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
#  THIS SOFTWARE IS PROVIDED BY THE AUTHOR "AS IS" AND ANY EXPRESS OR IMPLIED
#  WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
#  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO
#  EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
#  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
#  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
#  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
#  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
#  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

set -e
set -o pipefail

# terse package install for installpkg
export TERSE=0

# renovate: datasource=github-tags depName=SlackBuildsOrg/slackbuilds versioning=loose
SBO_RELEASE_VERSION="15.0-20250315.1"
wget -O - "https://github.com/SlackBuildsOrg/slackbuilds/tarball/$SBO_RELEASE_VERSION" | tar xz

export TAG=_aclemons
export PKGTYPE=txz

(
  cd SlackBuildsOrg-slackbuilds-*

  cd development/rust-opt

  # shellcheck source=/dev/null
  . rust-opt.info

  # shellcheck disable=SC2154
  wget "$DOWNLOAD_x86_64"
  # shellcheck disable=SC2154
  printf "%s\t%s\n" "$MD5SUM_x86_64" "$(basename "$DOWNLOAD_x86_64")" | md5sum --check --quiet
  bash rust-opt.SlackBuild
)

rm -rf SlackBuildsOrg-slackbuilds-*
rm -rf /tmp/SBo
