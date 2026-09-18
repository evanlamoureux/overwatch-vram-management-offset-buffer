#!/usr/bin/env bash
# ============================================================================
# Overwatch VRAM Usage Offset Buffer - Uninstaller
# ============================================================================
set -eu

echo "Uninstalling Overwatch VRAM Usage Offset Buffer..."

# 1. Stop and disable the systemd service
if systemctl list-unit-files | grep -qw "overwatch-vram-limit.service"; then
    sudo systemctl disable --now overwatch-vram-limit.service 2>/dev/null || true
    echo "Stopped and disabled systemd service."
fi

# 2. Remove the systemd service unit file
if [ -f /etc/systemd/system/overwatch-vram-limit.service ]; then
    sudo rm -f /etc/systemd/system/overwatch-vram-limit.service
    echo "Removed systemd service file."
fi

# 3. Reload systemd daemon to clear out the deleted unit
sudo systemctl daemon-reload
sudo systemctl reset-failed 2>/dev/null || true

# 4. Remove the core payload binary
if [ -f /usr/local/sbin/overwatch-vram-limit ]; then
    sudo rm -f /usr/local/sbin/overwatch-vram-limit
    echo "Removed payload script from /usr/local/sbin."
fi

echo "Overwatch has been completely removed from your system."
