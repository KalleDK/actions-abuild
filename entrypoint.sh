#!/usr/bin/env sh

set -e

echo "::group::Setup"

export PACKAGER="${INPUT_ABUILD_PACKAGER}"
export SRCDEST="${GITHUB_WORKSPACE}/cache/distfiles"
export REPODEST="${GITHUB_WORKSPACE}/packages"
export SUBREPO_BUILD="${REPODEST}/workspace"
export SUBREPO="${REPODEST}/acmednsproxy"

export PREFIX=${INPUT_ABUILD_PREFIX:-.}
export GIT_COMMIT=${INPUT_ABUILD_PKG_COMMIT}
export PKG_VER=${INPUT_ABUILD_PKG_REL}
export REPONAME=${INPUT_ABUILD_REPO_NAME}
export ABUILD_DIR=~/.abuild

# Set release
if [[ ! -z "${INPUT_ABUILD_PKG_REL}" ]]; then
  export PKG_REL=${INPUT_ABUILD_PKG_REL}
fi
mkdir -p ${SUBREPO_BUILD}
mkdir -p ${ABUILD_DIR}
echo ""

echo "::endgroup::"
echo "::group::Keys"

# Set signing keys
if [[ ! -z "${INPUT_ABUILD_KEY_NAME}" ]]; then
    echo "Using environment keys"
    export PACKAGER_PRIVKEY="${ABUILD_DIR}/${INPUT_ABUILD_KEY_NAME}.rsa"
    printf "${INPUT_ABUILD_KEY}" > "${PACKAGER_PRIVKEY}"

    export PACKAGER_PUBKEY="${ABUILD_DIR}/${INPUT_ABUILD_KEY_NAME}.rsa.pub"
    printf "${INPUT_ABUILD_KEY_PUB}" > "${PACKAGER_PUBKEY}"
    
    cp "${PACKAGER_PUBKEY}" /etc/apk/keys/
else
    echo "Using generated keys"
    abuild-keygen -a -i -n
    export PACKAGER_PUBKEY="${ABUILD_DIR}/$(ls -1rt ${ABUILD_DIR} | grep \.rsa\.pub | tail -n 1 | tail -n 1)"
fi
cp ${PACKAGER_PUBKEY} ${SUBREPO_BUILD}/

echo "::endgroup::"
echo "::group::Build"

cd ${PREFIX}
abuild -F checksum
abuild -F -r -P ${REPODEST} -s ${SRCDEST} -D ${REPONAME}
mv ${SUBREPO_BUILD} ${SUBREPO}
cd ${GITHUB_WORKSPACE}

echo "::endgroup::"
echo "::group::Verify"

find ${SUBREPO} -name "*.apk" | xargs apk verify

echo "::endgroup::"
