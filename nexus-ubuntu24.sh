#!/bin/bash
set -e

# === Konfigurasi dasar ===
LOG_DIR="/root/nexus_logs"

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
    echo -e "         Nexus CLI Node Manager"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# === Periksa dan install dependensi ===
function install_dependencies() {
    echo -e "${YELLOW}🛠 Memeriksa dependensi...${RESET}"
    apt update
    apt install -y curl screen git
}

# === Periksa dan install Nexus CLI ===
function install_nexus_cli() {
    if [ ! -f "$HOME/.nexus/bin/nexus-network" ]; then
        echo -e "${YELLOW}⬇ Menginstal Nexus CLI...${RESET}"
        curl -sSL https://cli.nexus.xyz/ | sh
    fi
    export PATH="$HOME/.nexus/bin:$PATH"
    echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> ~/.bashrc
}

# === Jalankan Node ===
function run_node() {
    read -rp "Masukkan NODE_ID: " NODE_ID
    [ -z "$NODE_ID" ] && echo "NODE_ID tidak boleh kosong." && sleep 2 && return
    screen -dmS nexus-${NODE_ID} bash -c "nexus-network start --node-id $NODE_ID && exec bash"
    echo -e "${GREEN}✔ Node $NODE_ID dijalankan di screen: screen -r nexus-${NODE_ID}${RESET}"
    sleep 2
}

# === Update Nexus CLI ===
function update_cli() {
    echo -e "${YELLOW}🔄 Memperbarui Nexus CLI...${RESET}"
    rm -rf $HOME/.nexus
    curl -sSL https://cli.nexus.xyz/ | sh
    echo -e "${GREEN}✔ CLI berhasil diperbarui.${RESET}"
    sleep 2
}

# === Lihat Log Node ===
function view_logs() {
    local screens=$(screen -ls | grep nexus- | awk '{print $1}')
    if [ -z "$screens" ]; then
        echo "Tidak ada node aktif."
        read -p "Tekan enter..." dummy
        return
    fi
    echo "Daftar screen aktif:"
    echo "$screens" | nl
    read -rp "Pilih nomor screen: " idx
    selected=$(echo "$screens" | sed -n "${idx}p")
    screen -r ${selected}
}

# === Hapus Semua Node ===
function uninstall_all() {
    for s in $(screen -ls | grep nexus- | awk '{print $1}'); do
        screen -S "$s" -X quit
    done
    echo -e "${YELLOW}❌ Semua node dihentikan.${RESET}"
    sleep 2
}

# === MENU UTAMA ===
while true; do
    show_header
    echo -e "${GREEN} 1.${RESET} ➕ Tambah & Jalankan Node"
    echo -e "${GREEN} 2.${RESET} 🔄 Update Nexus CLI"
    echo -e "${GREEN} 3.${RESET} 🧾 Lihat Log Node (screen)"
    echo -e "${GREEN} 4.${RESET} ❌ Hentikan Semua Node"
    echo -e "${GREEN} 5.${RESET} 🚪 Keluar"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Pilih menu (1-5): " pilihan
    case $pilihan in
        1)
            install_dependencies
            install_nexus_cli
            run_node
            ;;
        2) update_cli ;;
        3) view_logs ;;
        4) uninstall_all ;;
        5) exit 0 ;;
        *) echo "Pilihan tidak valid."; sleep 2 ;;
    esac

done
