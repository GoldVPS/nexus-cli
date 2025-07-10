#!/bin/bash
set -e

# === Basic Configuration ===
LOG_DIR="/root/nexus_logs"
mkdir -p "$LOG_DIR"

# === Terminal Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Header Display ===
function show_header() {
    clear
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "         Nexus CLI Node Manager"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# === Check and Install Dependencies ===
function install_dependencies() {
    echo -e "${YELLOW}Checking dependencies...${RESET}"
    apt update
    apt install -y curl screen git
}

# === Export PATH Only ===
function install_nexus_cli() {
    export PATH="$HOME/.nexus/bin:$PATH"
    if ! grep -q 'export PATH="$HOME/.nexus/bin:$PATH"' ~/.bashrc; then
        echo 'export PATH="$HOME/.nexus/bin:$PATH"' >> ~/.bashrc
    fi
}

# === Run Node ===
function run_node() {
    read -rp "Enter NODE_ID: " NODE_ID
    [ -z "$NODE_ID" ] && echo "NODE_ID cannot be empty." && sleep 2 && return
    CMD="screen -dmS nexus-${NODE_ID} bash -c 'nexus-network start --node-id $NODE_ID && exec bash'"
    eval "$CMD"
    echo "$CMD" >> "$LOG_DIR/start_commands.log"
    echo -e "${GREEN}Node $NODE_ID started in screen session: screen -r nexus-${NODE_ID}${RESET}"
    sleep 2
}

# === Update Nexus CLI ===
update_cli() {
  echo -e "\nUpdating Nexus CLI...\n"
  sleep 1

  if ! command -v cargo &> /dev/null; then
    echo "Rust belum terinstall. Menginstall Rust..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
  fi

  rm -rf /root/nexus-cli
  git clone https://github.com/nexus-xyz/nexus-cli.git /root/nexus-cli
  cd /root/nexus-cli/clients/cli || exit
  cargo build --release

  cp target/release/nexus-network /usr/local/bin/nexus

  echo -e "\n✅ Nexus CLI berhasil diupdate dan dibuild dari source.\n"

  read -p "🔁 Ingin restart semua node agar pakai versi terbaru? (y/N): " restart
  if [[ "$restart" =~ ^[Yy]$ ]]; then
      restart_all_nodes
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
  echo -e "\n🚨 Uninstalling Nexus CLI..."
  rm -f /usr/local/bin/nexus
  rm -rf /root/nexus-cli

  read -p "Ingin uninstall Rust juga? (y/N): " uninstall_rust
  if [[ "$uninstall_rust" =~ ^[Yy]$ ]]; then
    rustup self uninstall -y
  fi

  echo -e "\n✅ Nexus CLI berhasil dihapus.\n"
}

# === Restart All Nodes ===
restart_all_nodes() {
    echo -e "${YELLOW}Restarting all Nexus nodes from saved commands...${RESET}"

    for session in $(screen -ls | grep nexus- | awk '{print $1}'); do
        screen -S "$(echo "$session" | cut -d. -f1)" -X quit
    done

    echo -e "${GREEN}All running nodes stopped.${RESET}"
    echo -e "Re-running nodes...\n"

    while IFS= read -r cmd; do
        eval "$cmd"
        sleep 1
    done < "$LOG_DIR/start_commands.log"

    echo -e "${GREEN}✅ All nodes restarted using the latest Nexus CLI binary.${RESET}"
    sleep 2
}

# === MAIN MENU ===
while true; do
    show_header
    echo -e "${GREEN} 1.${RESET} Add & Run Node"
    echo -e "${GREEN} 2.${RESET} Update Nexus CLI"
    echo -e "${GREEN} 3.${RESET} View Node Logs"
    echo -e "${GREEN} 4.${RESET} Stop All Nodes"
    echo -e "${GREEN} 5.${RESET} Exit"
    echo -e "${GREEN} 6.${RESET} Uninstall Nexus CLI"
    echo -e "${GREEN} 7.${RESET} Restart All Nodes"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Select an option (1-7): " pilihan
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
        7) restart_all_nodes ;;
        *) echo "Invalid option."; sleep 2 ;;
    esac
done
