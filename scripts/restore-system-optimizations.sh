#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo." >&2
    exit 1
fi

if [ "$#" -ne 1 ] || [ ! -d "$1" ]; then
    echo "Usage: $0 /var/backups/kare-optimizations/TIMESTAMP" >&2
    exit 1
fi

backup_dir=$(CDPATH= cd -- "$1" && pwd)
case "$backup_dir" in
    /var/backups/kare-optimizations/*) ;;
    *)
        echo "The backup must be under /var/backups/kare-optimizations/." >&2
        exit 1
        ;;
esac

restore_file() {
    backup_name=$1
    target_path=$2

    if [ -e "$backup_dir/$backup_name" ] || [ -L "$backup_dir/$backup_name" ]; then
        install -d -m 0755 "$(dirname -- "$target_path")"
        rm -f "$target_path"
        cp -a "$backup_dir/$backup_name" "$target_path"
    elif [ -e "$backup_dir/$backup_name.absent" ]; then
        rm -f "$target_path"
    else
        echo "Missing backup marker for $target_path." >&2
        exit 1
    fi
}

systemctl disable --now kare-performance.service 2>/dev/null || true

restore_file kare-set-performance-governor /usr/local/sbin/kare-set-performance-governor
restore_file kare-performance.service /etc/systemd/system/kare-performance.service
restore_file 90-kare-performance.cfg /etc/default/grub.d/90-kare-performance.cfg
restore_file launch_desktop.sh /home/arduino/launch_desktop.sh
restore_file configure_desktop.sh /home/arduino/configure_desktop.sh
restore_file sleep.target /etc/systemd/system/sleep.target
restore_file suspend.target /etc/systemd/system/suspend.target
restore_file hibernate.target /etc/systemd/system/hibernate.target
restore_file hybrid-sleep.target /etc/systemd/system/hybrid-sleep.target
restore_file suspend-then-hibernate.target /etc/systemd/system/suspend-then-hibernate.target

if [ ! -s "$backup_dir/default-target" ]; then
    echo "The backup does not contain a default target." >&2
    exit 1
fi

systemctl daemon-reload
if [ -e "$backup_dir/kare-performance.enabled" ]; then
    systemctl enable kare-performance.service
elif [ -e "$backup_dir/kare-performance.disabled" ]; then
    systemctl disable kare-performance.service 2>/dev/null || true
else
    echo "The backup does not contain the service enable state." >&2
    exit 1
fi
if [ -e "$backup_dir/kare-performance.active" ]; then
    systemctl start kare-performance.service
elif [ ! -e "$backup_dir/kare-performance.inactive" ]; then
    echo "The backup does not contain the service active state." >&2
    exit 1
fi
systemctl set-default "$(cat "$backup_dir/default-target")"
update-grub

echo "Restored the configuration from $backup_dir."
echo "Reboot to use the restored kernel command line."
