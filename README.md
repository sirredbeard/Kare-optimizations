# Kare optimizations for Arduino VENTUNO Q

This is a small, reversible set of host changes for running [Kare](https://github.com/sirredbeard/Kare) on an Arduino VENTUNO Q.

Kare itself is not changed. This repository only configures the stock Ubuntu 24.04.5 host and it's installed `6.8.0-1084-qcom` kernel.

The board checked on October 2, 2026 reports:

```text
arduino,monza
qcom,monaco-monza
qcom,qcs8300
```

It has 8 ARM CPUs in three frequency policies:

| Policy | CPUs | Capacity | Frequency |
| --- | --- | ---: | ---: |
| `policy0` | 0-1 | 915 | 902.4-2112.0 MHz |
| `policy2` | 2-3 | 1024 | 940.8-2361.6 MHz |
| `policy4` | 4-7 | 446 | 844.8-1958.4 MHz |

CPUs 0-3 are Cortex-A78C cores. CPUs 4-7 are Cortex-A55 cores.

## Changes

The changes are deliberately boring:

- Boot to `multi-user.target`. GDM and GNOME remain installed and can be started on demand.
- Set all three CPU-frequency policies to the `performance` governor after the board's `sysfsutils` defaults run.
- Add `cpufreq.default_governor=performance` to the kernel command line as an early default.
- Add `consoleblank=0` so the Linux virtual console does not blank.
- Mask systemd suspend and hibernation targets.
- Disable GNOME idle blanking, screen locking, dimming, and automatic suspend for the `arduino` user.
- Install `~/launch_desktop.sh` to start `graphical.target` without changing the boot default.

The stock image contains `/etc/sysfs.d/50-dragonwing-defaults.conf`, which sets `policy0` and `policy4` back to `schedutil`. The systemd unit in this repository runs after `sysfsutils.service`, rather than racing it like the first version did.

The board also has `power-profiles-daemon`, however it exposes only placeholder `balanced` and `power-saver` profiles on this hardware. I did not install Tuned or add a second power-policy manager just to fight the first one.

## Apply

Run:

```sh
cd ~/Kare-optimizatinos
sudo ./scripts/apply-system-optimizations.sh
```

The script checks for `arduino,monza`, writes a timestamped backup under `/var/backups/kare-optimizations/`, installs the files, changes the default target, masks sleep, regenerates GRUB, and restarts the CPU policy service.

It does not reboot, stop the current desktop, change Kare, disable Arduino services, replace the kernel, or build a kernel.

The GNOME settings are user settings. Apply them from the `arduino` account:

```sh
./scripts/configure-desktop.sh
```

The script is safe to repeat. It configures both AC and battery inactivity policies, even though the VENTUNO Q is normally mains powered.

Reboot once for the two kernel arguments to take effect:

```sh
sudo reboot
```

## Desktop on demand

The default boot remains headless. Start GNOME when it is needed:

```sh
~/launch_desktop.sh
```

Returning to the text target for the current boot will stop the graphical session:

```sh
sudo systemctl isolate multi-user.target
```

## Validate

After the reboot:

```sh
systemctl get-default
systemctl is-enabled kare-performance.service
systemctl status kare-performance.service --no-pager
systemctl is-enabled sleep.target suspend.target hibernate.target \
    hybrid-sleep.target suspend-then-hibernate.target
cat /proc/cmdline

for policy in /sys/devices/system/cpu/cpufreq/policy*; do
    printf '%s: ' "$policy"
    cat "$policy/scaling_governor"
done
```

Expected results:

```text
multi-user.target
enabled
masked
masked
masked
masked
masked
cpufreq.default_governor=performance
consoleblank=0
performance
performance
performance
```

When GNOME is running:

```sh
gsettings get org.gnome.desktop.session idle-delay
gsettings get org.gnome.desktop.screensaver lock-enabled
gsettings get org.gnome.settings-daemon.plugins.power idle-dim
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type
gsettings get org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type
```

The expected values are `uint32 0`, `false`, `false`, `'nothing'`, and `'nothing'`.

## Roll back

Pass the backup directory created by the apply script:

```sh
sudo ./scripts/restore-system-optimizations.sh \
    /var/backups/kare-optimizations/20261002T000000Z
```

The restore script puts the previous files and default target back, reloads systemd, and regenerates GRUB. Reboot after restoring kernel command-line configuration.

## Why these settings

The Linux CPUFreq documentation says the `performance` governor requests the highest frequency allowed by each policy. That is useful for sustained local inference, however it raises power use and heat. The VENTUNO Q checked here was about 35-39 C while idle, and Kare recorded 43.3 C during sustained CPU generation. Thermals still need to be watched with the final model.

Kare's October 2, 2026 research says prompt processing costs about 15 ms per prompt token on the CPU path, while the board has roughly 14 GiB of usable memory and no swap. Predictable CPU frequency helps that workload. It does not make model size, prompt length, context reuse, or the eventual QNN and GenieX paths unimportant.

`multi-user.target` avoids starting the display manager and GNOME during normal headless operation. On this board, `multi-user.target` was reached after 19.207 seconds, with `NetworkManager-wait-online.service`, Docker, and `arduino-app-cli.service` on the critical path. I left those services alone because Kare needs networking and the Arduino application stack is part of the board.

`consoleblank=0` only controls the Linux virtual console. GNOME has it's own settings, which is why `configure-desktop.sh` exists. The masked systemd sleep targets are the final guard against suspend and hibernation requests.

## Deliberately not changed

I did not add `mitigations=off`, `isolcpus`, `nohz_full`, `rcu_nocbs`, `idle=poll`, `audit=0`, `nowatchdog`, `transparent_hugepage=always`, swap, zram, or a different eMMC scheduler.

The CPU isolation options need an IRQ, workqueue, RCU, and housekeeping CPU design around a measured process placement. `isolcpus` is also deprecated in favor of cpusets for scheduler-domain isolation. Four fast cores and four efficiency cores do not leave much room for casual isolation hackery.

The current transparent huge page policy is already `madvise`. The eMMC scheduler is already `mq-deadline`. Both are reasonable defaults, and there is no Kare measurement supporting a change.

Disabling security mitigations, auditing, watchdogs, or CPU idle states would trade security, diagnostics, thermals, or power for a result we have not measured. No.

## Sources

- [Kare](https://github.com/sirredbeard/Kare)
- [Arduino VENTUNO Q documentation](https://docs.arduino.cc/hardware/ventuno-q/)
- [Linux CPU performance scaling](https://docs.kernel.org/admin-guide/pm/cpufreq.html)
- [Linux kernel parameters](https://docs.kernel.org/admin-guide/kernel-parameters.html)
- [Linux CPU isolation](https://docs.kernel.org/admin-guide/cpu-isolation.html)
- [systemd unit ordering](https://www.freedesktop.org/software/systemd/man/latest/systemd.unit.html)
- [systemd boot targets](https://www.freedesktop.org/software/systemd/man/latest/systemd.special.html)

## License

MIT. See `LICENSE`.
