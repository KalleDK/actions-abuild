#!/usr/bin/env sh

set -e

echo "::group::Setup"

export PACKAGER="${INPUT_ABUILD_PACKAGER}"
export SRCDEST="${GITHUB_WORKSPACE}/cache/distfiles"
export REPODEST="${GITHUB_WORKSPACE}/packages"
export SUBREPO_BUILD="${REPODEST}/workspace"
export REPONAME=${INPUT_ABUILD_REPO_NAME}
export SUBREPO="${REPODEST}/${REPONAME}"
export BASE_URL=${INPUT_ABUILD_REPO_URL}

export PREFIX=${INPUT_ABUILD_PREFIX:-.}
export GIT_COMMIT=${INPUT_ABUILD_PKG_COMMIT}
export PKG_VER=${INPUT_ABUILD_PKG_VER}
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
export KEY_NAME=$(basename -s .rsa.pub ${PACKAGER_PUBKEY})
echo "::set-output name=key_name::${KEY_NAME}"

echo "::endgroup::"
echo "::group::Build"

cd ${PREFIX}
abuild -F checksum
abuild -F -r -P ${REPODEST} -s ${SRCDEST} -D ${REPONAME}
mv ${SUBREPO_BUILD} ${SUBREPO}
echo "::set-output name=repo_path::./packages"
cd ${GITHUB_WORKSPACE}

echo "::endgroup::"
echo "::group::Verify"

find ${SUBREPO} -name "*.apk" | xargs apk verify

echo "::endgroup::"


echo "::group::GenerateIndex"

if [[ ! -z "${INPUT_ABUILD_KEY_NAME}" ]]; then
echo "generating index"

cat << EOF > ${SUBREPO}/index.md
# ACME DNS Proxy

\`\`\`bash
# Install key
wget -O "/etc/apk/keys/${KEY_NAME}.rsa.pub" "${BASE_URL}/${REPONAME}/${KEY_NAME}.rsa.pub"

# Install repo
echo "${BASE_URL}/${REPONAME}" >> /etc/apk/repositories
\`\`\` 
EOF

cat ${SUBREPO}/index.md
else
echo "skipping due to missing url"
fi

echo "::endgroup::"