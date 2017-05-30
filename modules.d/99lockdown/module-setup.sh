#!/bin/bash

# called by dracut
check() {
    return 255
}

# called by dracut
depends() {
    return 0
}

# called by dracut
installkernel() {
    return 0
}

# called by dracut
install() {
    inst_hook cleanup 99 $moddir/lockdown-modules.sh
}
