import subprocess
import time
import os
from datetime import datetime

previous_rx = 0
previous_tx = 0

def clear_screen():
    os.system('clear')

def get_wg_data():
    result = subprocess.run(['wg', 'show', 'all', 'dump'], capture_output=True, text=True)
    lines = result.stdout.strip().split('\n')

    if len(lines) < 2:
        return None

    data = lines[1].split('\t')

    return {
            "pubkey": data[1][:8] + "...",
            "endpoint": data[3],
            "handshake": int(data[5]),
            "rx_bytes": int(data[6]),
            "tx_bytes": int(data[7])
            }

def format_bytes(bytes_num):
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_num < 1024.0:
            return f"{bytes_num:.2f} {unit}"
        bytes_num /=1024.0


while True:
    wg_data = get_wg_data()

    if wg_data:
        current_time = int(time.time())
        handshake_ago = current_time - wg_data['handshake']

        rx_speed_bytes = wg_data['rx_bytes'] - previous_rx
        tx_speed_bytes = wg_data['tx_bytes'] - previous_tx

        rx_kbps = (rx_speed_bytes * 8)/1000
        tx_kbps = (tx_speed_bytes * 8)/1000

        previous_rx = wg_data['rx_bytes']
        previous_tx = wg_data['tx_bytes']

        clear_screen()
        print("="*50)
        print(" ☁️ AWS HYBRID CLOUD NETWORK MONITOR ☁️")
        print("="*50)
        print(f"PEER:           {wg_data['pubkey']}")
        print(f"ENDPOINT IP:    {wg_data['endpoint']}")
        print(f"HANDSHAKE:      {handshake_ago} seconds ago (Status: {'✅ OK' if handshake_ago < 150 else '❌ STALE'})")
        print("="*50)
        print(f"LIVE SPEED IN:  {rx_kbps:.2f}Kbps")
        print(f"LIVE SPEED OUT: {tx_kbps:.2f}Kbps")
        print("="*50)
        print("Press Ctrl+C to exit")

    time.sleep(1)
