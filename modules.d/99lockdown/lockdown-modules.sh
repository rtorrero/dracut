#!/bin/sh

getargbool 1 rd.lockdown && (echo 1 >/proc/sys/kernel/modules_disabled)
