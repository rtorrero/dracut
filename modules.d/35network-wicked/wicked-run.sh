#!/bin/sh

dracut/modules.d/35network-wicked/wicked-run.sh
# detection wrapper around ifup --ifconfig "final xml" all
wicked bootstrap --ifconfig /tmp/dracut.xml all
