#!/bin/bash

echo "[*] Initializing Arch Host Bridge Environment..."

echo "[*] Starting WineGuard interface (wg0)..."
sudo wg-quick up wg0 || echo "wg0 might already be up, continuing..."

echo "[*] Creating TAP interface (tap0)..."
sudo ip tuntap add dev tap0 mode tap user $(whoami) 2>/dev/null || echo "tap0 might already exist..."

echo "[*] Assigning 10.10.10.1 to tap0..."
sudo ip addr add 10.10.10.1/24 dev tap0 || echo "Ip might already be assigned..."

sudo ip link set tap0 up

echo "[*] Host network ready. Booting Virtual machine via Expect..."

expect << 'EOF'
set timeout -1

spawn qemu-system-x86_64 \
  -enable-kvm \
  -m 1024 \
  -cdrom /home/fajlur/Downloads/alpine-virt-3.23.4-x86_64.iso \
  -netdev tap,id=mynet0,ifname=tap0,script=no,downscript=no \
  -device virtio-net-pci,netdev=mynet0 \
  -nographic


expect "localhost login:"
send "root\r"

expect "localhost:~#"

send "echo 'Injecting Network Config...'\r"
expect "localhost:~#"

send "ip addr add 10.10.10.2/24 dev eth0\r"
expect "localhost:~#"

send "ip link set eth0 up\r"
expect "localhost:~#"

send "ip route add default via 10.10.10.1\r"
expect "localhost:~#"


send "echo 'Configuration Complete. Testing Ping to AWS...'\r"
expect "localhost:~#"

send "ping -c 3 10.200.200.1\r"
expect "localhost:~#"

interact
EOF

echo ""
echo "[!] VM Closed, BUT INFRASTRUCTURE IS STILL ALIVE!"
echo "[!] The tap0 interface and wg0 tunnel are standing by for Phase 2 testing."
echo "[!] Run ./teardown.sh when you are completely finished."
