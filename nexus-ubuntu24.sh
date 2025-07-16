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

# === Check and Install Dependencies ===
function install_nexus_cli() {
    if [ ! -f "$HOME/.nexus/bin/nexus-network" ]; then
        echo -e "${YELLOW}Installing Nexus CLI...${RESET}"

        TMPFILE=$(mktemp)

        # Jalankan installer dan tampilkan output ke layar & file
        bash -c "curl -sSL https://cli.nexus.xyz/ | bash" | tee "$TMPFILE"

        # Deteksi apakah CLI gagal terinstall karena binary tidak tersedia
        if grep -q "Please build from source" "$TMPFILE"; then
            echo -e "${RED}Precompiled binary not available. Building manually from source...${RESET}"
            update_cli
        elif grep -q "Do you agree to the Nexus Beta Terms" "$TMPFILE"; then
            echo -e "${RED}❌ Gagal otomatis install karena butuh input interaktif (Terms of Use).${RESET}"
            echo -e "Silakan install manual atau lanjut build dari source..."
            update_cli
        else
            echo -e "${GREEN}✅ Nexus CLI installed successfully.${RESET}"
        fi

        rm -f "$TMPFILE"
    fi

    export PATH="$HOME/.nexus/bin:$PATH"
    if ! grep -q 'nexus/bin' ~/.bashrc; then
        echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> ~/.bashrc
    fi
}

# === Update Nexus CLI ===
update_cli() {
  echo -e "\n\e[1;33mUpdating Nexus CLI from source...\e[0m\n"
  sleep 1

  # Ambil semua node id dari nama screen nexus-
  active_nodes=$(screen -ls | grep nexus- | awk -F'nexus-' '{print $2}' | awk '{print $1}')

  # Unset legacy CLI install from ~/.nexus if exists
  rm -rf ~/.nexus
  sed -i '/.nexus\/bin/d' ~/.bashrc

  # Cek dan install Rust kalau belum ada
  if ! command -v cargo &> /dev/null; then
    echo -e "\e[33mRust belum terinstall. Menginstall Rust...\e[0m"
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
    echo 'source "$HOME/.cargo/env"' >> ~/.bashrc
  else
    source "$HOME/.cargo/env"
  fi

  # Install deps tambahan buat build Rust
  apt install -y build-essential pkg-config libssl-dev libclang-dev cmake

  # Hapus repo lama jika ada
  rm -rf /root/nexus-cli

  # Clone repo dan build ulang
  cd /root || exit 1
  git clone https://github.com/nexus-xyz/nexus-cli.git || {
    echo -e "\n\e[31m❌ Gagal meng-clone repository Nexus CLI.\e[0m\n"
    return 1
  }

  cd nexus-cli/clients/cli || {
    echo -e "\n\e[31m❌ Folder build tidak ditemukan.\e[0m\n"
    return 1
  }

  cargo build --release || {
    echo -e "\n\e[31m❌ Gagal build Nexus CLI dengan cargo.\e[0m\n"
    return 1
  }

  # Pastikan hasil build ada
  if [ ! -f target/release/nexus-network ]; then
    echo -e "\n\e[31m❌ File binary nexus-network tidak ditemukan setelah build.\e[0m\n"
    return 1
  fi

  # Copy hasil build ke /usr/local/bin
  cp target/release/nexus-network /usr/local/bin/nexus

  # Kembali ke direktori awal
  cd ~

  echo -e "\n✅ \e[32mNexus CLI berhasil diupdate dan dibuild dari source.\e[0m\n"

  read -p "Ingin otomatis restart node yang aktif? (Y/n): " restart_choice
  if [[ "$restart_choice" =~ ^[Yy]$ || -z "$restart_choice" ]]; then
    echo -e "\n🔁 \e[36mRestarting previously active nodes...\e[0m"
    for s in $(screen -ls | grep nexus- | awk '{print $1}'); do
      screen -S "$s" -X quit
    done
    for id in $active_nodes; do
      screen -dmS nexus-${id} bash -c "nexus start --node-id $id && exec bash"
      echo "✅ Node $id restarted."
    done
  else
    echo -e "\n⚠️  \e[33mSelesai update. Jika sebelumnya ada node aktif, silakan jalankan ulang via menu 1.\e[0m"
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

