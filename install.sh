#!/usr/bin/env bash
# ============================================================================
# Overwatch VRAM Usage Offset Buffer - Universal Installer
# ============================================================================
set -eu

# 1. Pre-flight check: Verify VRAM Management (dmem cgroup) is available
if [ ! -f /sys/fs/cgroup/dmem.capacity ]; then
    echo "ERROR: VRAM Management (dmem controller) is not detected on this system." >&2
    echo "Ensure your kernel supports cgroup dmem (e.g., CachyOS with dmem patches)." >&2
    exit 1
fi

# 2. Dynamically determine the target user (handles whoever runs sudo)
TARGET_USER="${SUDO_USER:-$USER}"
if [ "$TARGET_USER" = "root" ]; then
    echo "ERROR: Please run this script as your regular user with sudo, e.g.: sudo ./install.sh" >&2
    exit 1
fi

TARGET_UID=$(id -u "$TARGET_USER")
CG_BASE="/sys/fs/cgroup/user.slice/user-${TARGET_UID}.slice/user@${TARGET_UID}.service"
APP_CG="${CG_BASE}/app.slice"

echo "Installing Overwatch for user: ${TARGET_USER} (UID: ${TARGET_UID})..."

# 3. Clean up old or conflicting services
sudo systemctl disable --now overwatch-vram-limit.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/overwatch-vram-limit.service

# 4. Write the payload script to /usr/local/sbin with dynamic paths
sudo tee /usr/local/sbin/overwatch-vram-limit >/dev/null << EOF
#!/bin/bash

RESERVE_MIB=50
APP_CG="${APP_CG}"
USER_CG=\$(dirname "\$APP_CG")

# Wait for app.slice to exist
for i in \$(seq 1 120); do
    if [ -d "\$APP_CG" ]; then break; fi
    sleep 1
done

if [ ! -d "\$APP_CG" ]; then
    echo "Overwatch ERROR: app.slice was never created by systemd." >&2
    exit 1
fi

# Wait for dmem controller
for i in \$(seq 1 120); do
    if grep -qw "dmem" "\${USER_CG}/cgroup.controllers" 2>/dev/null; then break; fi
    sleep 1
done

if ! grep -qw "dmem" "\${USER_CG}/cgroup.controllers" 2>/dev/null; then
    echo "Overwatch ERROR: dmem controller unavailable on parent cgroup." >&2
    exit 1
fi

# Enable dmem controller on subtree
echo "+dmem" > "\${USER_CG}/cgroup.subtree_control" 2>/dev/null || true

# Wait for dmem.max file to generate
for i in \$(seq 1 50); do
    if [ -f "\$APP_CG/dmem.max" ]; then break; fi
    sleep 0.1
done

if [ ! -f "\$APP_CG/dmem.max" ]; then
    echo "Overwatch ERROR: Failed to inherit dmem controller." >&2
    exit 1
fi

# Read and parse GPU VRAM capacity (supports NVIDIA vidmem and AMD/Intel vram)
DMEM_INFO=\$(grep -E "(vidmem|vram)" /sys/fs/cgroup/dmem.capacity | sort -nrk2 | head -n1)
if [ -z "\$DMEM_INFO" ]; then
    echo "Overwatch ERROR: Could not find a valid GPU in dmem.capacity." >&2
    exit 1
fi

DEVICE=\$(echo "\$DMEM_INFO" | awk '{print \$1}')
CAPACITY=\$(echo "\$DMEM_INFO" | awk '{print \$2}')
TARGET=\$((CAPACITY - (RESERVE_MIB * 1024 * 1024)))

if [ "\$TARGET" -gt 0 ]; then
    echo "\$DEVICE \$TARGET" > "\$APP_CG/dmem.max"
    echo "Overwatch successfully applied: \$DEVICE limited to \$TARGET bytes (\${RESERVE_MIB}MiB reserved)."
fi
EOF

sudo chmod 755 /usr/local/sbin/overwatch-vram-limit

# 5. Create the systemd service unit dynamically matching the user UID
sudo tee /etc/systemd/system/overwatch-vram-limit.service >/dev/null << EOF
[Unit]
Description=Overwatch: Apply VRAM safety limit
After=user@${TARGET_UID}.service
Requires=user@${TARGET_UID}.service

[Service]
Type=oneshot
RemainAfterExit=yes
TimeoutStartSec=180
ExecStart=/usr/local/sbin/overwatch-vram-limit

[Install]
WantedBy=multi-user.target
EOF

# 6. Reload, enable, and start the service
sudo systemctl daemon-reload
sudo systemctl enable --now overwatch-vram-limit.service

echo "Overwatch successfully installed and initialized!"
