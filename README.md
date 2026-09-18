# Overwatch VRAM Usage Offset Buffer

A lightweight systemd service designed for Linux that automatically caps foreground process VRAM usage (via systemd's `app.slice` and the kernel's `dmem` cgroup controller) by a configurable safety offset—preventing full system freezes, crashes, and severe stutters when applications max out your GPU memory.

## What Problem Does This Solve?

On Linux systems running graphics-heavy desktop sessions or games, running completely out of VRAM can occasionally lock up the desktop environment or cause unrecoverable stutters. 

Instead of constantly monitoring memory in the background, **Overwatch** runs once at boot, queries your GPU's actual hardware capacity, subtracts a small safety buffer (default: 50 MiB), and hands the hard limit over to the Linux kernel via cgroups (`dmem.max`). Once applied, the kernel handles the enforcement natively with zero idle overhead.

## How It Works

1. **Pre-flight Check:** Verifies that your kernel supports the `dmem` cgroup controller (common on performance-focused distributions like CachyOS).
2. **Waits for Boot:** Waits patiently for your user session and `app.slice` to initialize.
3. **Detects Hardware:** Dynamically reads `/sys/fs/cgroup/dmem.capacity` to find your primary GPU (`vidmem` or `vram`) and its exact capacity.
4. **Calculates the Limit:** Subtracts your configured margin (e.g., `CAPACITY - 50 MiB`).
5. **Applies & Exits:** Applies the ceiling to `app.slice` and exits immediately. 

## Requirements

* A Linux kernel with `dmem` cgroup controller support (such as CachyOS).
* Systemd.

## Installation

1. Clone or download this repository.
2. Review or modify the script parameters if you want to change the safety margin (default is `RESERVE_MIB=50`).
3. Run the installer script:

```bash
chmod +x install.sh
sudo ./install.sh
```

## Verification

You can verify that the service applied successfully and check the kernel's active limit at any time with:

```bash
systemctl status overwatch-vram-limit.service
cat /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/dmem.max
```

## License

This software is provided under a custom non-commercial license. See the `LICENSE` file for details.
