#!/bin/bash
set -e

# === Warna terminal ===
GREEN='\033[0;32m'
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

# === Periksa screen ===
function check_screen() {
    if ! command -v screen >/dev/null 2>&1; then
        echo -e "${YELLOW}Menginstal screen...${RESET}"
        apt update && apt install -y screen
    fi
}

# === Tambah & Jalankan Node ===
function add_node() {
    check_screen
    read -rp "Masukkan satu atau lebih NODE_ID (pisahkan spasi): " input
    [ -z "$input" ] && echo "NODE_ID wajib diisi." && sleep 2 && return

    mkdir -p "$HOME/.nexus/nodes"

    for id in $input; do
        screen -dmS "nexus-$id" bash -c "curl -sSL https://cli.nexus.xyz/ | sh && export PATH=\$HOME/.nexus/bin:\$PATH && sleep 5 && nexus-network start --node-id $id && exec bash"
        touch "$HOME/.nexus/nodes/$id"
        echo -e "${GREEN}Node $id dijalankan di screen: screen -r nexus-$id${RESET}"
    done
    read -p "Tekan enter..." dummy
}

# === Daftar Node ===
function list_nodes() {
    show_header
    echo -e "${CYAN}📊 Daftar Node Terdaftar:${RESET}"
    local list=( $(ls $HOME/.nexus/nodes 2>/dev/null) )
    for i in "${!list[@]}"; do
        local id=${list[$i]}
        local running=$(screen -ls | grep -q "nexus-$id" && echo "running" || echo "stopped")
        echo "$((i+1)). Node ID: $id | Status: $running"
    done
    read -p "Tekan enter..." dummy
}

# === Lihat Log Node ===
function view_logs() {
    local list=( $(ls $HOME/.nexus/nodes 2>/dev/null) )
    echo "Pilih node untuk lihat log:"
    for i in "${!list[@]}"; do
        echo "$((i+1)). ${list[$i]}"
    done
    read -rp "Nomor: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#list[@]} )); then
        screen -r "nexus-${list[$((choice-1))]}"
    fi
}

# === Hapus Semua Node ===
function uninstall_all_nodes() {
    echo -e "${YELLOW}Menghapus semua node...${RESET}"
    pkill -f "nexus-network start" || true
    rm -rf "$HOME/.nexus/nodes"
    echo -e "${GREEN}✔ Semua node dihapus.${RESET}"
    read -p "Tekan enter..." dummy
}

# === Update Nexus CLI dan Restart Node ===
function update_cli() {
    echo -e "${YELLOW}🔄 Update Nexus CLI...${RESET}"
    pkill -f "nexus-network start" || true
    sleep 3
    rm -f "$HOME/.nexus/bin/nexus-network"
    curl -sSL https://cli.nexus.xyz/ | sh
    ln -sf "$HOME/.nexus/bin/nexus-cli" "$HOME/.nexus/bin/nexus-network"
    echo -e "${GREEN}✔ Nexus CLI berhasil di-update.${RESET}"

    local node_list=( $(ls "$HOME/.nexus/nodes" 2>/dev/null) )
    for id in "${node_list[@]}"; do
        echo -e "${CYAN}🔁 Restarting node $id...${RESET}"
        screen -dmS "nexus-$id" bash -c "nexus-network start --node-id $id && exec bash"
    done
    read -p "Tekan enter..." dummy
}

# === MENU UTAMA ===
while true; do
    show_header
    echo -e "${GREEN} 1.${RESET} ➕ Tambah & Jalankan Node"
    echo -e "${GREEN} 2.${RESET} 📊 Lihat Status Semua Node"
    echo -e "${GREEN} 3.${RESET} 🧾 Lihat Log Node"
    echo -e "${GREEN} 4.${RESET} ❌ Hapus Semua Node"
    echo -e "${GREEN} 5.${RESET} 🔄 Update Nexus CLI"
    echo -e "${GREEN} 6.${RESET} 🚪 Keluar"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Pilih menu (1-6): " pilihan
    case $pilihan in
        1) add_node ;;
        2) list_nodes ;;
        3) view_logs ;;
        4) uninstall_all_nodes ;;
        5) update_cli ;;
        6) exit 0 ;;
        *) echo "Pilihan tidak valid."; sleep 2 ;;
    esac
done
