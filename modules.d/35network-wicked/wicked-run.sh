#!/bin/sh

# detection wrapper around ifup --ifconfig "final xml" all
wicked bootstrap --ifconfig /tmp/dracut.xml all
