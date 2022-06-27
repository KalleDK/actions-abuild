#!/usr/bin/env sh

echo "::group::Setup"

export REPODEST="${GITHUB_WORKSPACE}/packages"
export SRCDEST="${GITHUB_WORKSPACE}/cache/distfiles"
export PACKAGER="${INPUT_ABUILD_PACKAGER}"

export PREFIX=${INPUT_ABUILD_PREFIX:-.}
export GIT_COMMIT=${INPUT_ABUILD_PKG_COMMIT}
export PKG_VER=${INPUT_ABUILD_PKG_REL}

# Set release
if [[ ! -z "${INPUT_ABUILD_PKG_REL}" ]]; then
  export PKG_REL=${INPUT_ABUILD_PKG_REL}
fi
echo ""

echo "::endgroup::"
echo "::group::Keys"

# Set signing keys
if [[ ! -z "${INPUT_ABUILD_KEY_NAME}" ]]; then
    echo "Using environment keys"
    export PACKAGER_PRIVKEY="/root/${INPUT_ABUILD_KEY_NAME}.rsa"
    printf "${INPUT_ABUILD_KEY}" > "${PACKAGER_PRIVKEY}"

    export PACKAGER_PUBKEY="/root/${INPUT_ABUILD_KEY_NAME}.rsa.pub"
    printf "${INPUT_ABUILD_KEY_PUB}" > "${PACKAGER_PUBKEY}"
    
    cp "${PACKAGER_PUBKEY}" /etc/apk/keys/
else
    echo "Using generated keys"
    abuild-keygen -a -i -n
fi

echo "::endgroup::"
echo "::group::Build"

cd ${PREFIX}
abuild -F checksum
abuild -F -r
cd ${GITHUB_WORKSPACE}

echo "::endgroup::"
echo "::group::Verify"

find $REPODEST -name "*.apk" | xargs apk verify
find . -name "*.apk" | head -1 | xargs dirname | xargs -I %  echo "::set-output name=packages_path::%"
echo "::endgroup::"
