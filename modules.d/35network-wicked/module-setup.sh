#!/bin/bash

# called by dracut
check() {
    local _program

    require_binaries wicked || return 1

    # do not add this module by default
    return 255
}

# called by dracut
depends() {
    echo systemd dbus
    return 0
}

# called by dracut
installkernel() {
    return 0
}

# called by dracut
install() {
    inst_hook cmdline 99 "$moddir/wicked-config.sh"

    # Seems to not execute if in initqueue/settled
    inst_hook pre-mount 99 "$moddir/wicked-run.sh"

    inst_dir /etc/wicked/extensions
    inst_dir /usr/share/wicked/schema
    inst_dir /usr/lib/wicked/bin
    inst_dir /var/lib/wicked

    inst_multiple /etc/wicked/*.xml
    inst_multiple /etc/wicked/extensions/*
    inst_multiple /etc/dbus-1/system.d/org.opensuse.Network*
    inst_multiple /usr/share/wicked/schema/*
    inst_multiple /usr/lib/wicked/bin/*
    inst_multiple /usr/sbin/wicked*
    inst_multiple /var/lib/wicked/{duid,iaid}.xml

    cat >"$initdir/$systemdsystemunitdir/wickedd.service" <<-EOF
        [Unit]
        Description=wicked network management service daemon
        DefaultDependencies=no
        Conflicts=shutdown.target
        Requires=dbus.service
        Wants=wickedd-nanny.service wickedd-dhcp6.service wickedd-dhcp4.service wickedd-auto4.service
        After=sysinit.target dbus.service
        Before=wickedd-nanny.service basic.target shutdown.target

        [Service]
        Type=notify
        LimitCORE=infinity
        ExecStart=/usr/sbin/wickedd --systemd --foreground
        StandardError=null
        Restart=on-abort

        [Install]
        WantedBy=basic.target
        Also=wickedd-nanny.service
        Also=wickedd-auto4.service
        Also=wickedd-dhcp4.service
        Also=wickedd-dhcp6.service
EOF

    cat >"$initdir/$systemdsystemunitdir/wickedd-auto4.service" <<-EOF
        [Unit]
        Description=wicked AutoIPv4 supplicant service
        DefaultDependencies=no
        Conflicts=shutdown.target
        Requires=dbus.service
        After=sysinit.target dbus.service
        Before=wickedd.service basic.target shutdown.target
        PartOf=wickedd.service

        [Service]
        Type=notify
        LimitCORE=infinity
        ExecStart=/usr/lib/wicked/bin/wickedd-auto4 --systemd --foreground
        StandardError=null
        Restart=on-abort

        [Install]
        Alias=dbus-org.opensuse.Network.AUTO4.service
EOF

    cat >"$initdir/$systemdsystemunitdir/wickedd-dhcp4.service" <<-EOF
        [Unit]
        Description=wicked DHCPv4 supplicant service
        DefaultDependencies=no
        Conflicts=shutdown.target
        Requires=dbus.service
        After=sysinit.target dbus.service
        Before=wickedd.service basic.target shutdown.target
        PartOf=wickedd.service

        [Service]
        Type=notify
        LimitCORE=infinity
        ExecStart=/usr/lib/wicked/bin/wickedd-dhcp4 --systemd --foreground
        StandardError=null
        Restart=on-abort

        [Install]
        Alias=dbus-org.opensuse.Network.DHCP4.service
EOF

    cat >"$initdir/$systemdsystemunitdir/wickedd-dhcp6.service" <<-EOF
        [Unit]
        Description=wicked DHCPv6 supplicant service
        DefaultDependencies=no
        Conflicts=shutdown.target
        Requires=dbus.service
        After=sysinit.target dbus.service
        Before=wickedd.service basic.target shutdown.target
        PartOf=wickedd.service

        [Service]
        Type=notify
        LimitCORE=infinity
        ExecStart=/usr/lib/wicked/bin/wickedd-dhcp6 --systemd --foreground
        StandardError=null
        Restart=on-abort

        [Install]
        Alias=dbus-org.opensuse.Network.DHCP6.service
EOF

    cat >"$initdir/$systemdsystemunitdir/wickedd-nanny.service" <<-EOF
        [Unit]
        Description=wicked network nanny service
        DefaultDependencies=no
        Conflicts=shutdown.target
        Requires=dbus.service
        After=dbus.service wickedd.service
        Before=basic.target shutdown.target
        PartOf=wickedd.service

        [Service]
        Type=notify
        LimitCORE=infinity
        EnvironmentFile=-/etc/sysconfig/network/config
        ExecStart=/usr/sbin/wickedd-nanny --systemd --foreground
        StandardError=null
        Restart=on-abort

        [Install]
        Alias=dbus-org.opensuse.Network.Nanny.service
EOF

    systemctl --root "$initdir" enable wickedd.service > /dev/null 2>&1
}
