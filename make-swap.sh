#!/usr/bin/env bash
set -e

# ==============================
#  FLEXIBLE SWAP CREATOR
#  systemd persistent (no fstab)
# ==============================

if [ "$(id -u)" != "0" ]; then
  echo "ERROR: run as root"
  exit 1
fi

SWAPFILE="/swapfile"
UNIT_NAME="swapfile.swap"
UNIT_PATH="/etc/systemd/system/${UNIT_NAME}"

echo "======================================"
echo "   SYSTEMD SWAPFILE INSTALLER"
echo "======================================"
echo ""
echo "Choose swap size:"
echo "1) 1 GB"
echo "2) 2 GB"
echo "3) 4 GB"
echo "4) 8 GB"
echo ""
echo "Auto default 2GB in 10 seconds..."
echo ""

read -t 10 -p "Select [1-4]: " CHOICE || true

case "$CHOICE" in
  1) SIZE="1G" ;;
  2) SIZE="2G" ;;
  3) SIZE="4G" ;;
  4) SIZE="8G" ;;
  *) SIZE="2G" ;;
esac

echo ""
echo "Selected swap size: $SIZE"
echo ""

# ==============================
# remove old swap if exists
# ==============================

if swapon --show | grep -q "$SWAPFILE"; then
  echo "Existing swap active -> disabling"
  swapoff "$SWAPFILE"
fi

if [ -f "$UNIT_PATH" ]; then
  echo "Removing old systemd swap unit"
  systemctl disable --now "$UNIT_NAME" 2>/dev/null || true
  rm -f "$UNIT_PATH"
fi

if [ -f "$SWAPFILE" ]; then
  echo "Removing old swapfile"
  rm -f "$SWAPFILE"
fi

# ==============================
# create swapfile
# ==============================

echo "Creating swapfile..."

if fallocate -l "$SIZE" "$SWAPFILE" 2>/dev/null; then
  echo "fallocate OK"
else
  echo "fallocate unsupported -> using dd"
  SIZE_MB=$(numfmt --from=iec "$SIZE")
  SIZE_MB=$((SIZE_MB / 1024 / 1024))
  dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE_MB" status=progress
fi

chmod 600 "$SWAPFILE"
mkswap "$SWAPFILE"

# ==============================
# create systemd swap unit
# ==============================

echo "Creating systemd swap unit..."

ESCAPED=$(systemd-escape --path "$SWAPFILE")
UNIT_NAME="${ESCAPED}.swap"
UNIT_PATH="/etc/systemd/system/${UNIT_NAME}"

cat > "$UNIT_PATH" <<EOF
[Unit]
Description=Custom Swap File
After=local-fs.target

[Swap]
What=$SWAPFILE

[Install]
WantedBy=swap.target
EOF

# ==============================
# enable + start
# ==============================

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now "$UNIT_NAME"

echo ""
echo "======================================"
echo "   SWAP INSTALLED SUCCESSFULLY"
echo "======================================"
echo ""

swapon --show
free -h | grep -i swap

echo ""
echo "Systemd unit:"
echo "$UNIT_NAME"
echo ""
echo "Reboot persistent: YES"
echo ""
rm make-swap.sh
