#!/bin/bash

. ${LIBDIR}/util.sh

MP_CONF_GLOB='/etc/makepkg.conf'
MP_CONF_USER="${USER_HOME}/.makepkg.conf"

usage() {
    echo ''
    echo "Usage: ${0##*/} [options]"
    echo ''
    echo '     -b <branch> Branch to use (arm-unstable/arm-testing/arm-stable'
    echo '                                default: arm-unstable)'
    echo '     -c          Start with clean chroot fs'
    echo '     -h          This help'
#   echo '     -i <pkg>    Install pkg to chroot fs'
    echo '     -n          Install built pkg to chroot fs'
    echo '     -r          Remove previously built packages in $PKGDEST'
    echo '     -s          Sign package'
    echo ''
    exit $1
}

query_conf() {
    echo "$(grep "^$1" "$2" | tail -1 | cut -d= -f2)"
}

get_mp_conf() {
    [[ -f ${MP_CONF_USER} ]] && CONF=$(query_conf $1 ${MP_CONF_USER})
    [[ -z ${CONF} ]] && CONF=$(query_conf $1 ${MP_CONF_GLOB})
    echo ${CONF//\"/}
}

get_config() {
    echo $(get_mp_conf $1)
}

rm_pkgs() {
    if [ ! -z ${PKG_DIR} ]; then
        msg5 "Removing previously built packages from [${PKG_DIR}]."
        rm ${PKG_DIR}/*.pkg.tar.zst{,.sig} &>/dev/null
    fi
}

sign_pkg() {
    local pkg
    GPGKEY=$(get_config GPGKEY)
    PKGEXT=$(query_conf PKGEXT "${CHROOT_DIR}${MP_CONF_GLOB}")

    msg2 "Signing $1 with key ${GPGKEY}"
    pkg="${1}*${PKGEXT}"
    gpg --detach-sign --use-agent -u "${GPGKEY}" "$pkg"
}

build_pkg() {
    local sign
    msg "Configure mirrorlist for branch [${BRANCH}]"
    echo "Server = ${MIRROR}/${BRANCH}/\$repo/\$arch" > "${CHROOT_DIR}/etc/pacman.d/mirrorlist"

    rm -rf ${BUILD_DIR}/.[!.]*
    cp -r $1 ${BUILD_DIR}
    rm -rf ${BUILD_DIR}/$1/{pkg,src}/
    chown -R ${BUILDUSER_UID}:${BUILDUSER_GID} ${BUILD_DIR}/$1

    [[ $INSTALL = true ]] && mp_opts='fsi' || mp_opts='fs'
    [[ $SIGNPKG = true ]] && sign=' --sign'
    chroot ${CHROOT_DIR} chrootbuild $1 $mp_opts $sign
    
    cd ${CHROOT_DIR}/pkgdest
    [[ ${SIGNPKG} = true ]] && sign_pkg $1
    [[ ! -z ${PKG_DIR} ]] && mv $1*.{xz,zst,sig} ${PKG_DIR}/ 2>/dev/null
}
