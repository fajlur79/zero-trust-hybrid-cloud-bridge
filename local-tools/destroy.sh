#!/bin/bash

echo "[*] Tearing down hybrid cloud environment..."

sudo ip link set tap0 down 2>/dev/null
sudo ip tuntap del dev tap0 mode tap 2>/dev/null
echo "[*] tap0 interface destroyed."

sudo wg-quick down wg0 2>/dev/null
echo "[*] WireGuard tunnel closed."

echo "[*] Environment successfully cleaned up!"