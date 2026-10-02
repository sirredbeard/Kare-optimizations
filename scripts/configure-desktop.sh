#!/bin/sh
set -eu

if [ "$(id -u)" -eq 0 ]; then
    echo "Run this script as the desktop user, not root." >&2
    exit 1
fi

gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver ubuntu-lock-on-suspend false
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type nothing
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type nothing
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 0

echo "Disabled GNOME idle blanking, locking, dimming, and automatic suspend."
