#!/bin/bash
set -e

# === Warna terminal ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Header Tampilan ===
function show_header() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "           Nexus CLI Node Manager"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# === Periksa & install dependencies ===
function check_dependencies() {
    echo -e "${CYAN}⏳ Memeriksa dependencies...${RESET}"
    apt update
    apt install -y curl wget screen
}

# === Jalankan Nexus CLI ===
function start_node() {
    read -rp "Masukkan NODE_ID: " NODE_ID
    [ -z "$NODE_ID" ] && echo "NODE_ID wajib diisi." && sleep 2 && return

    screen_name="nexus-${NODE_ID}"
    screen -dmS "$screen_name" bash -c "echo Y | nexus-network start --node-id $NODE_ID && exec bash"
    echo -e "${GREEN}Node $NODE_ID dijalankan di screen: screen -r $screen_name${RESET}"
    sleep 2
}

# === Update Nexus CLI ===
function update_cli() {
    echo -e "${YELLOW}🔄 Update Nexus CLI...${RESET}"
    curl -sSL https://cli.nexus.xyz/ | sh
    export PATH="$HOME/.nexus/bin:$PATH"
    echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
    echo -e "${GREEN}✔ Nexus CLI berhasil di-update.${RESET}"
    read -p "Tekan enter..." dummy
}

# === Lihat node yang sedang jalan ===
function list_nodes() {
    echo -e "${CYAN}📋 Daftar screen aktif untuk Nexus:${RESET}"
    screen -ls | grep nexus || echo "Tidak ada screen Nexus yang aktif."
    read -p "Tekan enter..." dummy
}

# === Hapus semua screen nexus ===
function stop_all_nodes() {
    for s in $(screen -ls | grep nexus | awk '{print $1}'); do
        screen -S $(echo $s | cut -d. -f1) -X quit
    done
    echo -e "${YELLOW}❌ Semua screen Nexus dimatikan.${RESET}"
    read -p "Tekan enter..." dummy
}

# === MENU UTAMA ===
while true; do
    show_header
    echo -e "${GREEN} 1.${RESET} ➕ Tambah & Jalankan Node"
    echo -e "${GREEN} 2.${RESET} 🔄 Update Nexus CLI"
    echo -e "${GREEN} 3.${RESET} 📋 Lihat Screen Aktif"
    echo -e "${GREEN} 4.${RESET} ❌ Matikan Semua Node"
    echo -e "${GREEN} 5.${RESET} 🚪 Keluar"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Pilih menu (1-5): " pilihan
    case $pilihan in
        1) check_dependencies; start_node ;;
        2) update_cli ;;
        3) list_nodes ;;
        4) stop_all_nodes ;;
        5) exit 0 ;;
        *) echo "Pilihan tidak valid."; sleep 2 ;;
    esac

done
