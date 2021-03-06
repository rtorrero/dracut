#!/bin/sh

mount_boot()
{
    boot=$(getarg boot=)

    if [ -n "$boot" ]; then
        case "$boot" in
        LABEL=*)
            boot="$(echo $boot | sed 's,/,\\x2f,g')"
            boot="/dev/disk/by-label/${boot#LABEL=}"
            ;;
        UUID=*)
            boot="/dev/disk/by-uuid/${boot#UUID=}"
            ;;
        PARTUUID=*)
            boot="/dev/disk/by-partuuid/${boot#PARTUUID=}"
            ;;
        PARTLABEL=*)
            boot="/dev/disk/by-partlabel/${boot#PARTLABEL=}"
            ;;
        /dev/*)
            ;;
        *)
            die "You have to specify boot=<boot device> as a boot option for fips=1" ;;
        esac

        if ! [ -e "$boot" ]; then
            udevadm trigger --action=add >/dev/null 2>&1
            [ -z "$UDEVVERSION" ] && UDEVVERSION=$(udevadm --version)
            i=0
            while ! [ -e $boot ]; do
                if [ $UDEVVERSION -ge 143 ]; then
                    udevadm settle --exit-if-exists=$boot
                else
                    udevadm settle --timeout=30
                fi
                [ -e $boot ] && break
                sleep 0.5
                i=$(($i+1))
                [ $i -gt 40 ] && break
            done
        fi

        [ -e "$boot" ] || return 1

        mkdir /boot
        info "Mounting $boot as /boot"
        mount -oro "$boot" /boot || return 1
    elif [ -d "$NEWROOT/boot" ]; then
        rm -fr -- /boot
        ln -sf "$NEWROOT/boot" /boot
    fi
}

do_rhevh_check()
{
    KERNEL=$(uname -r)
    kpath=${1}
    FIPSCHECK=/usr/lib64/libkcapi/fipscheck
    if [ ! -f $FIPSCHECK ]; then
        FIPSCHECK=/usr/lib/libkcapi/fipscheck
    fi
    if [ ! -f $FIPSCHECK ]; then
        FIPSCHECK=/usr/bin/fipscheck
    fi
    # If we're on RHEV-H, the kernel is in /run/initramfs/live/vmlinuz0
    if $FIPSCHECK $NEWROOT/boot/vmlinuz-${KERNEL} ; then
        warn "HMAC sum mismatch"
        return 1
    fi
    info "rhevh_check OK"
    return 0
}

do_fips()
{
    local _v
    local _s
    local _v
    local _module
    local _arch=$(uname -m)
    local _vmname=vmlinuz

    if [ "$_arch" == "s390x" ]; then
        _vmname=image
    fi

    KERNEL=$(uname -r)
    FIPSCHECK=/usr/lib64/libkcapi/fipscheck
    if [ ! -f $FIPSCHECK ]; then
        FIPSCHECK=/usr/lib/libkcapi/fipscheck
    fi
    if [ ! -f $FIPSCHECK ]; then
        FIPSCHECK=/usr/bin/fipscheck
    fi

    if ! [ -e "/boot/.${_vmname}-${KERNEL}.hmac" ]; then
        warn "/boot/.${_vmname}-${KERNEL}.hmac does not exist"
        return 1
    fi

    FIPSMODULES=$(cat /etc/fipsmodules)

    info "Loading and integrity checking all crypto modules"
    mv /etc/modprobe.d/fips.conf /etc/modprobe.d/fips.conf.bak
    for _module in $FIPSMODULES; do
        if [ "$_module" != "tcrypt" ]; then
            if ! modprobe "${_module}"; then
                # check if kernel provides generic algo
                _found=0
                while read _k _s _v || [ -n "$_k" ]; do
                    [ "$_k" != "name" -a "$_k" != "driver" ] && continue
                    [ "$_v" != "$_module" ] && continue
                    _found=1
                    break
                done </proc/crypto
                # If we find some hardware specific modules and cannot load them
                # it is not a problem, proceed.
                if [ "$_found" = "0" ]; then
                    if [    "$_module" != "${_module%intel}"    \
                        -o  "$_module" != "${_module%ssse3}"    \
                        -o  "$_module" != "${_module%x86_64}"   \
                        -o  "$_module" != "${_module%z90}"      \
                        -o  "$_module" != "${_module%s390}"     \
                        -o  "$_module" == "twofish_x86_64_3way" \
                        -o  "$_module" == "ablk_helper"         \
                        -o  "$_module" == "glue_helper"         \
                    ]; then
                        _found=1
                    fi
                fi

                [ "$_found" = "0" ] && return 1
            fi
        fi
    done
    mv /etc/modprobe.d/fips.conf.bak /etc/modprobe.d/fips.conf

    info "Self testing crypto algorithms"
    modprobe tcrypt || return 1
    rmmod tcrypt

    info "Checking integrity of kernel"
    if [ -e "/run/initramfs/live/vmlinuz0" ]; then
        do_rhevh_check /run/initramfs/live/vmlinuz0 || return 1
    elif [ -e "/run/initramfs/live/isolinux/vmlinuz0" ]; then
        do_rhevh_check /run/initramfs/live/isolinux/vmlinuz0 || return 1
    else
        $FIPSCHECK "/boot/${_vmname}-${KERNEL}" || return 1
    fi

    info "All initrd crypto checks done"

    > /tmp/fipsdone

    umount /boot >/dev/null 2>&1

    return 0
}
