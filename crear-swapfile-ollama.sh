#!/usr/bin/env bash
set -e

SWAPFILE=/swapfile_ollama
SIZE=32G

if [ -f "$SWAPFILE" ]; then
    echo "Ya existe $SWAPFILE, cancelo (borralo a mano si querés rehacerlo)."
    exit 1
fi

echo "Creando swapfile btrfs-safe de $SIZE en $SWAPFILE..."
btrfs filesystem mkswapfile --size "$SIZE" "$SWAPFILE"

echo "Activando swap..."
swapon "$SWAPFILE"

if ! grep -q "$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw,pri=10 0 0" >> /etc/fstab
    echo "Agregado a /etc/fstab (persiste tras reinicio)."
fi

echo "---"
swapon --show
echo "---"
free -h
