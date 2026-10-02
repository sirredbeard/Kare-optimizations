#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
    exec systemctl isolate graphical.target
fi

exec sudo systemctl isolate graphical.target
