#!/bin/bash
set -e

# === Konfigurasi dasar ===
LOG_DIR="/root/nexus_logs"

# === Warna terminal ===
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Header Tampilan ===
function show_header() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "           Nexus Ubuntu 24.04 Node"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# === Cek & install dependensi ===
function check_dependencies() {
    apt update
    apt install -y curl screen git build-essential pkg-config libssl-dev
}

# === Install Nexus CLI ===
function install_nexus_cli() {
    if [ ! -f "$HOME/.nexus/bin/nexus-network" ]; then
        echo -e "${YELLOW}🚀 Menginstall Nexus CLI...${RESET}"
        curl -sSL https://cli.nexus.xyz/ | sh
        echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> ~/.bashrc
        export PATH="$HOME/.nexus/bin:$PATH"
    fi
}

# === Update Nexus CLI ===
function update_nexus_cli() {
    echo -e "${YELLOW}🔄 Update Nexus CLI...${RESET}"
    curl -sSL https://cli.nexus.xyz/ | sh
    echo -e "${GREEN}✔ Nexus CLI berhasil di-update.${RESET}"
    read -p "Tekan enter..."
}

# === Jalankan node ===
function run_node() {
    read -rp "Masukkan satu atau lebih NODE_ID (pisahkan spasi): " input
    [ -z "$input" ] && echo "NODE_ID wajib diisi." && sleep 2 && return
    for id in $input; do
        local screen_name="nexus-${id}"
        screen -dmS "$screen_name" bash -c "nexus-network start --node-id $id && exec bash"
        echo -e "${GREEN}Node $id dijalankan di screen: screen -r $screen_name${RESET}"
    done
    read -p "Tekan enter..."
}

# === Lihat screen aktif ===
function list_nodes() {
    show_header
    echo -e "${CYAN}📊 Daftar Node Berjalan (screen):${RESET}"
    screen -ls | grep nexus || echo "Tidak ada node Nexus yang berjalan."
    read -p "Tekan enter..."
}

# === Lihat log dari screen ===
function view_logs() {
    screen -ls | grep nexus | awk '{print NR". "$1}'
    read -rp "Pilih nomor screen (1-n): " num
    screen_id=$(screen -ls | grep nexus | awk "NR==$num {print \$1}")
    if [ -n "$screen_id" ]; then
        screen -r "$screen_id"
    else
        echo "Tidak ditemukan."
    fi
}

# === Hentikan semua screen nexus ===
function stop_all_nodes() {
    screen -ls | grep nexus | awk '{print $1}' | while read id; do
        screen -S "$id" -X quit
    done
    echo -e "${YELLOW}⚠ Semua screen node dihentikan.${RESET}"
    read -p "Tekan enter..."
}

# === MENU UTAMA ===
function main_menu() {
    while true; do
        show_header
        echo -e "${GREEN} 1.${RESET} ➕ Jalankan Node"
        echo -e "${GREEN} 2.${RESET} 📊 Lihat Status Semua Node (screen)"
        echo -e "${GREEN} 3.${RESET} 🧾 Lihat Log Node (screen)"
        echo -e "${GREEN} 4.${RESET} ❌ Hentikan Semua Node"
        echo -e "${GREEN} 5.${RESET} 🔄 Update Nexus CLI"
        echo -e "${GREEN} 6.${RESET} 🚪 Keluar"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
        read -rp "Pilih menu (1-6): " pilihan
        case $pilihan in
            1) run_node ;;
            2) list_nodes ;;
            3) view_logs ;;
            4) stop_all_nodes ;;
            5) update_nexus_cli ;;
            6) exit 0 ;;
            *) echo "Pilihan tidak valid."; sleep 2 ;;
        esac
    done
}

# === Eksekusi awal ===
check_dependencies
install_nexus_cli
main_menu
