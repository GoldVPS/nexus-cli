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

# === Check and Install Dependencies ===
function install_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${RESET}"
    apt update
    apt install -y curl screen git build-essential pkg-config libssl-dev libclang-dev cmake
}

# === Install Nexus CLI if not already present ===
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

    # Install build tools
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

# === Run Node ===
function run_node() {
    read -rp "Enter NODE_ID: " NODE_ID
    [ -z "$NODE_ID" ] && echo "NODE_ID cannot be empty." && sleep 2 && return
    screen -dmS nexus-${NODE_ID} bash -c "nexus start --node-id $NODE_ID && exec bash"
    echo -e "${GREEN}Node $NODE_ID started in screen session: screen -r nexus-${NODE_ID}${RESET}"
    sleep 2
}

# === Update Nexus CLI ===
update_cli() {
  echo -e "\nUpdating Nexus CLI from source...\n"
  sleep 1

  # Ambil semua node id dari nama screen nexus-
  active_nodes=$(screen -ls | grep nexus- | awk -F'nexus-' '{print $2}' | awk '{print $1}')

  # Unset legacy CLI install from ~/.nexus if exists
  rm -rf ~/.nexus
  sed -i '/.nexus\/bin/d' ~/.bashrc

  # Cek dan install Rust kalau belum ada
  if ! command -v cargo &> /dev/null; then
    echo "Rust belum terinstall. Menginstall Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
  fi

  # Install deps tambahan buat build Rust
  apt install -y build-essential pkg-config libssl-dev libclang-dev cmake

  # Hapus repo lama jika ada
  rm -rf /root/nexus-cli

  # Clone repo dan build ulang
  cd /root || exit
  git clone https://github.com/nexus-xyz/nexus-cli.git
  cd nexus-cli/clients/cli || exit
  cargo build --release

  # Copy hasil build ke /usr/local/bin agar bisa dipanggil global
  cp target/release/nexus-network /usr/local/bin/nexus

  # Kembali ke direktori awal
  cd ~

  echo -e "\n✅ Nexus CLI berhasil diupdate dan dibuild dari source.\n"

  read -p "Ingin otomatis restart node yang aktif? (Y/n): " restart_choice
  if [[ "$restart_choice" =~ ^[Yy]$ || -z "$restart_choice" ]]; then
    echo -e "\n🔁 Restarting previously active nodes..."
    for s in $(screen -ls | grep nexus- | awk '{print $1}'); do
      screen -S "$s" -X quit
    done
    for id in $active_nodes; do
      screen -dmS nexus-${id} bash -c "nexus start --node-id $id && exec bash"
      echo "✅ Node $id restarted."
    done
  else
    echo -e "\n⚠️  Selesai update. Jika sebelumnya ada node aktif, silakan jalankan ulang via menu 1."
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
    screen -r ${selected}
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

  # Hapus binary
  rm -f /usr/local/bin/nexus-network

  # Hapus folder source jika ada
  rm -rf /root/nexus-cli

  # Opsional: hapus Rust jika cuma buat Nexus
  read -p "Ingin uninstall Rust juga? (y/N): " uninstall_rust
  if [[ "$uninstall_rust" =~ ^[Yy]$ ]]; then
    rustup self uninstall -y
  fi

  echo -e "\n✅ Nexus CLI berhasil dihapus.\n"
}

# === MAIN MENU ===
# === MAIN MENU ===
while true; do
    show_header
    echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -e "  \e[1;32m1.\e[0m Add & Run Node"
    echo -e "  \e[1;32m2.\e[0m Update Nexus CLI"
    echo -e "  \e[1;32m3.\e[0m View Node Logs"
    echo -e "  \e[1;32m4.\e[0m Stop All Nodes"
    echo -e "  \e[1;32m5.\e[0m Exit"
    echo -e "  \e[1;32m6.\e[0m Uninstall Nexus CLI"
    echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"

    echo -ne "\n\e[1;36mSelect an option (1-6): \e[0m"
    read -r pilihan

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
        6) uninstall_cli ;;
        *) echo -e "\e[31mInvalid option.\e[0m"; sleep 2 ;;
    esac
done
