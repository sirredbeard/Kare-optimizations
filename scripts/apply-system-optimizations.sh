#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

compatible=$(tr '\0' '\n' < /sys/firmware/devicetree/base/compatible 2>/dev/null || true)
case "$compatible" in
    *arduino,monza*) ;;
    *)
        echo "This script only applies to an Arduino VENTUNO Q (arduino,monza)." >&2
        exit 1
        ;;
esac

backup_dir="/var/backups/kare-optimizations/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 0700 "$backup_dir"

backup_file() {
    source_path=$1
    backup_name=$2

    if [ -e "$source_path" ] || [ -L "$source_path" ]; then
        cp -a "$source_path" "$backup_dir/$backup_name"
    else
        : > "$backup_dir/$backup_name.absent"
    fi
}

systemctl get-default > "$backup_dir/default-target"
if systemctl is-enabled --quiet kare-performance.service; then
    : > "$backup_dir/kare-performance.enabled"
else
    : > "$backup_dir/kare-performance.disabled"
fi
if systemctl is-active --quiet kare-performance.service; then
    : > "$backup_dir/kare-performance.active"
else
    : > "$backup_dir/kare-performance.inactive"
fi
backup_file /usr/local/sbin/kare-set-performance-governor kare-set-performance-governor
backup_file /etc/systemd/system/kare-performance.service kare-performance.service
backup_file /etc/default/grub.d/90-kare-performance.cfg 90-kare-performance.cfg
backup_file /home/arduino/launch_desktop.sh launch_desktop.sh
backup_file /home/arduino/configure_desktop.sh configure_desktop.sh
backup_file /etc/systemd/system/sleep.target sleep.target
backup_file /etc/systemd/system/suspend.target suspend.target
backup_file /etc/systemd/system/hibernate.target hibernate.target
backup_file /etc/systemd/system/hybrid-sleep.target hybrid-sleep.target
backup_file /etc/systemd/system/suspend-then-hibernate.target suspend-then-hibernate.target

install -D -m 0755 "$repo_dir/scripts/kare-set-performance-governor" \
    /usr/local/sbin/kare-set-performance-governor
install -D -m 0644 "$repo_dir/systemd/kare-performance.service" \
    /etc/systemd/system/kare-performance.service
install -D -m 0644 "$repo_dir/grub/90-kare-performance.cfg" \
    /etc/default/grub.d/90-kare-performance.cfg
install -m 0755 "$repo_dir/scripts/launch-desktop.sh" /home/arduino/launch_desktop.sh
install -m 0755 "$repo_dir/scripts/configure-desktop.sh" /home/arduino/configure_desktop.sh
chown arduino:arduino /home/arduino/launch_desktop.sh /home/arduino/configure_desktop.sh

systemctl daemon-reload
systemctl enable kare-performance.service
systemctl restart kare-performance.service
systemctl set-default multi-user.target
systemctl mask sleep.target suspend.target hibernate.target \
    hybrid-sleep.target suspend-then-hibernate.target
update-grub

echo "Applied CPU performance policy persistence."
echo "Set the default boot target to multi-user.target."
echo "Masked systemd suspend and hibernation targets."
echo "Added the CPU governor and console blanking kernel arguments."
echo "Installed /home/arduino/launch_desktop.sh and configure_desktop.sh."
echo "Run configure_desktop.sh as the arduino user, then reboot."
echo "Backups are in $backup_dir."
