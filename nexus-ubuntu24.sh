#!/bin/bash
set -e

# === Basic Configuration ===
LOG_DIR="/root/nexus_logs"

# === Terminal Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Header Display ===
function show_header() {
    clear
    echo -e "\e[38;5;220m"
    echo " ██████╗  ██████╗ ██╗     ██████╗ ██╗   ██╗██████╗ ███████╗"
    echo "██╔════╝ ██╔═══██╗██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝"
    echo "██║  ███╗██║   ██║██║     ██║  ██║██║   ██║██████╔╝███████╗"
    echo "██║   ██║██║   ██║██║     ██║  ██║╚██╗ ██╔╝██╔═══╝ ╚════██║"
    echo "╚██████╔╝╚██████╔╝███████╗██████╔╝ ╚████╔╝ ██║     ███████║"
    echo " ╚═════╝  ╚═════╝ ╚══════╝╚═════╝   ╚═══╝  ╚═╝     ╚══════╝"
    echo -e "\e[0m"
    echo -e "🚀 \e[1;33mNexus Node Installer\e[0m - Powered by \e[1;33mGoldVPS Team\e[0m 🚀"
    echo -e "🌐 \e[4;33mhttps://goldvps.net\e[0m - Best VPS with Low Price"
    echo ""
}

# === Utils ===
ensure_logdir() { mkdir -p "$LOG_DIR"; }

start_node() {
  local id="$1"
  # Cek screen sudah ada
  if screen -ls | grep -q "nexus-$id"; then
    echo -e "${YELLOW}Lewati ${id}${RESET} (sudah berjalan)"
    return 1
  fi
  screen -dmS "nexus-$id" bash -c "exec nexus start --node-id $id >>'$LOG_DIR/nexus_${id}.log' 2>&1"
  echo -e "${GREEN}Start node ${id}${RESET}  → log: ${YELLOW}$LOG_DIR/nexus_${id}.log${RESET}"
  return 0
}

normalize_ids_from_string() {
  # stdin → normalized unique numeric/non-numeric tokens separated by newline
  # Ganti koma/semicolon jadi spasi, jadikan satu baris, squeeze spasi, trim
  local norm
  norm=$(cat | tr ',;' ' ' | tr -s ' ' | sed 's/^ *//;s/ *$//')
  printf "%s\n" $norm | sed '/^$/d' | sort -u
}

normalize_ids_from_file() {
  local file="$1"
  # Hapus komentar (# ...), gabung baris, ganti koma/semicolon jadi spasi
  # lalu dedup
  sed 's/#.*$//' "$file" | tr ',;' ' ' | tr '\n' ' ' | \
    tr -s ' ' | sed 's/^ *//;s/ *$//' | \
    awk '{for(i=1;i<=NF;i++) print $i}' | sort -u
}

# === Check and Install Dependencies ===
function install_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${RESET}"
    apt update
    apt install -y curl screen git build-essential pkg-config libssl-dev libclang-dev cmake
    ensure_logdir
}

# === Install Nexus CLI from Source ===
function install_nexus_cli() {
    if [ -f "/usr/local/bin/nexus" ]; then
        echo -e "${GREEN}Nexus CLI already installed.${RESET}"
        return
    fi

    echo -e "${YELLOW}Installing Nexus CLI from source...${RESET}"

    # Install Rust if not exists
    if ! command -v cargo &> /dev/null; then
        echo -e "${YELLOW}Installing Rust...${RESET}"
        curl https://sh.rustup.rs -sSf | sh -s -- -y
        source "$HOME/.cargo/env"
    fi

    # Build deps
    apt install -y build-essential pkg-config libssl-dev libclang-dev cmake

    # Clone & build from source
    rm -rf /root/nexus-cli
    git clone https://github.com/nexus-xyz/nexus-cli.git /root/nexus-cli
    cd /root/nexus-cli/clients/cli || {
        echo -e "${RED}Failed to access source directory.${RESET}"
        return
    }

    cargo build --release
    cp target/release/nexus-network /usr/local/bin/nexus

    echo -e "${GREEN}✅ Nexus CLI successfully installed from source.${RESET}"
}

# === Run Nodes (manual input, multiple) ===
function run_nodes() {
    echo -e "${CYAN}Masukkan satu atau lebih NODE_ID dipisahkan koma atau spasi.${RESET}"
    echo -e "Contoh: 7853397, 7853404 7881587"
    read -rp "Enter NODE_ID(s): " RAW_IDS

    IDS=($(echo "$RAW_IDS" | normalize_ids_from_string))
    if [ "${#IDS[@]}" -eq 0 ]; then
        echo -e "${RED}NODE_ID tidak boleh kosong.${RESET}"
        sleep 2
        return
    fi

    local ok=0 skip=0
    for id in "${IDS[@]}"; do
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            start_node "$id" && ((ok++)) || ((skip++))
        else
            echo -e "${YELLOW}Lewati ${id}${RESET} (bukan angka)"
            ((skip++))
        fi
    done

    echo -e "${GREEN}Selesai.${RESET} Start: $ok, Skip: $skip"
    echo -e "Attach: ${YELLOW}screen -r nexus-<NODE_ID>${RESET}"
    sleep 2
}

# === Run Nodes from File (batch) ===
function run_nodes_from_file() {
    echo -e "${CYAN}Path file daftar NODE_ID (default: /root/node_ids.txt)${RESET}"
    read -rp "File path: " FILE_PATH
    FILE_PATH=${FILE_PATH:-/root/node_ids.txt}

    if [ ! -f "$FILE_PATH" ]; then
        echo -e "${RED}File tidak ditemukan: ${FILE_PATH}${RESET}"
        sleep 2
        return
    fi

    # Ambil ID ter-normalisasi dari file
    mapfile -t IDS < <(normalize_ids_from_file "$FILE_PATH")
    if [ "${#IDS[@]}" -eq 0 ]; then
        echo -e "${RED}Tidak ada NODE_ID valid di file.${RESET}"
        sleep 2
        return
    fi

    echo -e "${YELLOW}Total kandidat ID:${RESET} ${#IDS[@]}"
    local ok=0 skip=0
    for id in "${IDS[@]}"; do
        if [[ "$id" =~ ^[0-9]+$ ]]; then
            start_node "$id" && ((ok++)) || ((skip++))
        else
            echo -e "${YELLOW}Lewati ${id}${RESET} (bukan angka)"
            ((skip++))
        fi
    done

    echo -e "${GREEN}Batch selesai.${RESET} Start: $ok, Skip: $skip"
    echo -e "Log dir: ${YELLOW}$LOG_DIR${RESET}"
    sleep 2
}

# === Update Nexus CLI ===
update_cli() {
  echo -e "\n${YELLOW}Updating Nexus CLI from source...${RESET}"
  sleep 1

  # Ambil semua node id dari screen session nexus-
  active_nodes=$(screen -ls | grep nexus- | awk -F'nexus-' '{print $2}' | awk '{print $1}')

  # Unset legacy ~/.nexus CLI
  rm -rf ~/.nexus
  sed -i '/.nexus\/bin/d' ~/.bashrc

  # Install Rust kalau belum ada
  if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}Rust belum terinstall. Menginstall Rust...${RESET}"
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
  fi

  # Build deps
  apt install -y build-essential pkg-config libssl-dev libclang-dev cmake

  # Stop all screen nodes
  for s in $(screen -ls | grep nexus- | awk '{print $1}'); do
    screen -S "$s" -X quit
  done
  sleep 2
  pkill -f "nexus start" 2>/dev/null || true

  # Rebuild
  rm -rf /root/nexus-cli
  git clone https://github.com/nexus-xyz/nexus-cli.git /root/nexus-cli
  cd /root/nexus-cli/clients/cli || {
    echo -e "${RED}❌ Gagal masuk ke direktori CLI source.${RESET}"
    return
  }

  echo -e "${YELLOW}Building Nexus CLI...${RESET}"
  cargo build --release

  mv /usr/local/bin/nexus /usr/local/bin/nexus.old 2>/dev/null || true
  cp target/release/nexus-network /usr/local/bin/nexus
  chmod +x /usr/local/bin/nexus

  cd ~
  echo -e "\n${GREEN}✅ Nexus CLI berhasil diupdate & diinstall dari source.${RESET}\n"

  # Restart nodes?
  read -p "Ingin otomatis restart node yang aktif? (Y/n): " restart_choice
  if [[ "$restart_choice" =~ ^[Yy]$ || -z "$restart_choice" ]]; then
    ensure_logdir
    echo -e "\n🔁 Restarting previously active nodes..."
    for id in $active_nodes; do
      screen -dmS "nexus-${id}" bash -c "exec nexus start --node-id $id >>'$LOG_DIR/nexus_${id}.log' 2>&1"
      echo -e "${GREEN}✅ Node $id restarted.${RESET}"
    done
  else
    echo -e "\n⚠️  ${YELLOW}Selesai update. Jalankan node manual via menu 1/7 jika dibutuhkan.${RESET}"
  fi
}

# === View Node Logs ===
function view_logs() {
    local screens=$(screen -ls | grep nexus- | awk '{print $1}')
    if [ -z "$screens" ]; then
        echo "No active node sessions found."
        read -p "Press enter to continue..." dummy
        return
    fi
    echo "Active screen sessions:"
    echo "$screens" | nl
    read -rp "Select screen number: " idx
    selected=$(echo "$screens" | sed -n "${idx}p")
    screen -r "${selected}"
}

# === Stop All Nodes ===
function uninstall_all() {
    for s in $(screen -ls | grep nexus- | awk '{print $1}'); do
        screen -S "$s" -X quit
    done
    echo -e "${YELLOW}All nodes have been stopped.${RESET}"
    sleep 2
}

# === Uninstall Nexus CLI ===
uninstall_cli() {
  echo -e "\n\ud83d\udea8 Uninstalling Nexus CLI..."

  rm -f /usr/local/bin/nexus /usr/local/bin/nexus-network
  rm -rf /root/nexus-cli

  read -p "Ingin uninstall Rust juga? (y/N): " uninstall_rust
  if [[ "$uninstall_rust" =~ ^[Yy]$ ]]; then
    rustup self uninstall -y
  fi

  echo -e "\n✅ Nexus CLI berhasil dihapus.\n"
}

# === MAIN MENU ===
while true; do
    show_header
    echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "  \e[1;32m1.\e[0m Add & Run Node(s)"
    echo -e "  \e[1;32m2.\e[0m Update Nexus CLI"
    echo -e "  \e[1;32m3.\e[0m View Node Logs"
    echo -e "  \e[1;32m4.\e[0m Stop All Nodes"
    echo -e "  \e[1;32m5.\e[0m Exit"
    echo -e "  \e[1;32m6.\e[0m Uninstall Nexus CLI"
    echo -e "  \e[1;32m7.\e[0m Add from file (batch)"
    echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

    echo -ne "\n\e[1;36mSelect an option (1-7): \e[0m"
    read -r pilihan

    case $pilihan in
        1)
            install_dependencies
            install_nexus_cli
            run_nodes
            ;;
        2) update_cli ;;
        3) view_logs ;;
        4) uninstall_all ;;
        5) exit 0 ;;
        6) uninstall_cli ;;
        7)
            install_dependencies
            install_nexus_cli
            run_nodes_from_file
            ;;
        *) echo -e "\e[31mInvalid option.\e[0m"; sleep 2 ;;
    esac
done
