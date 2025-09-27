#!/bin/bash
set -e

# === Config ===
BIN="/usr/local/bin/nexus"    # path absolut binary nexus
LOG_DIR="/root/nexus_logs"

# === Warna ===
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

# === Header ===
show_header() {
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
  echo
}

# === Utils ===
ensure_env() { mkdir -p "$LOG_DIR"; }
require_bin() {
  if ! [ -x "$BIN" ]; then
    echo -e "${RED}Binary tidak ditemukan/eksecutable: $BIN${RESET}"
    exit 1
  fi
}
have_screen() { command -v screen >/dev/null 2>&1; }

# Tokenize input string → daftar ID unik (satu per baris)
normalize_ids_from_string() {
  tr -d '\r' | tr ',;' ' ' | tr -s ' ' | sed 's/^ *//;s/ *$//' \
    | awk '{for(i=1;i<=NF;i++) print $i}' | sed '/^$/d' | sort -u
}
# Ambil ID dari file (support komentar '#', koma/spasi, CRLF)
normalize_ids_from_file() {
  local file="$1"
  tr -d '\r' <"$file" | sed 's/#.*$//' | tr ',;' ' ' | tr '\n' ' ' \
    | tr -s ' ' | sed 's/^ *//;s/ *$//' \
    | awk '{for(i=1;i<=NF;i++) print $i}' | sed '/^$/d' | sort -u
}

# Cek screen session eksak: 12345.nexus-<id>
sess_exists() {
  local id="$1"
  screen -ls | awk '{print $1}' | grep -qxE '[0-9]+\.'nexus-"$id"
}

# Start satu node dalam screen + logging, with bash -lc & throttle
start_node() {
  local id="$1"
  local sess="nexus-$id"

  if sess_exists "$id"; then
    echo -e "→ ${YELLOW}Lewati $id${RESET} (sudah berjalan)"
    return 0
  fi

  # jalankan via login shell agar env/ PATH benar; arahkan log
  screen -dmS "$sess" bash -lc "
    ulimit -n 65535 || true
    exec \"$BIN\" start --node-id \"$id\" >>\"$LOG_DIR/nexus_${id}.log\" 2>&1
  "

  # verifikasi benar-benar tercipta
  sleep 0.25
  if ! sess_exists "$id"; then
    echo -e "${RED}!! Gagal membuat screen untuk $id${RESET}"
    echo '[start_node] screen create failed' >>"$LOG_DIR/nexus_${id}.log"
    return 1
  fi

  echo -e "${GREEN}✓ Start $id${RESET}  → log: ${YELLOW}$LOG_DIR/nexus_${id}.log${RESET}"
  sleep 0.15
  return 0
}

# === Install/Update/Uninstall ===
install_dependencies() {
  echo -e "${YELLOW}Checking dependencies...${RESET}"
  apt update
  apt install -y curl screen git build-essential pkg-config libssl-dev libclang-dev cmake
  ensure_env
  have_screen || { echo -e "${RED}screen belum terpasang.${RESET}"; exit 1; }
}
install_nexus_cli() {
  if [ -x "$BIN" ]; then
    echo -e "${GREEN}Nexus CLI already installed.${RESET}"; return
  fi
  echo -e "${YELLOW}Installing Nexus CLI from source...${RESET}"
  if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
  fi
  apt install -y build-essential pkg-config libssl-dev libclang-dev cmake
  rm -rf /root/nexus-cli
  git clone https://github.com/nexus-xyz/nexus-cli.git /root/nexus-cli
  cd /root/nexus-cli/clients/cli || { echo -e "${RED}Failed to access CLI dir.${RESET}"; return; }
  cargo build --release
  cp target/release/nexus-network "$BIN"
  chmod +x "$BIN"
  echo -e "${GREEN}✅ Nexus CLI installed.${RESET}"
}
update_cli() {
  echo -e "\n${YELLOW}Updating Nexus CLI from source...${RESET}"
  local active_nodes
  active_nodes=$(screen -ls | grep nexus- | awk -F'nexus-' '{print $2}' | awk '{print $1}')

  # stop semuanya
  for s in $(screen -ls | grep -oE '[0-9]+\.(nexus-[0-9]+)'); do screen -S "$s" -X quit || true; done
  pkill -f "nexus start" 2>/dev/null || true

  # build ulang
  if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
  fi
  apt install -y build-essential pkg-config libssl-dev libclang-dev cmake
  rm -rf /root/nexus-cli
  git clone https://github.com/nexus-xyz/nexus-cli.git /root/nexus-cli
  cd /root/nexus-cli/clients/cli || { echo -e "${RED}❌ Gagal masuk ke CLI dir.${RESET}"; return; }
  cargo build --release
  mv "$BIN" "${BIN}.old" 2>/dev/null || true
  cp target/release/nexus-network "$BIN"; chmod +x "$BIN"
  cd ~
  echo -e "${GREEN}✅ Nexus CLI updated.${RESET}"

  read -p "Restart previously active nodes? (Y/n): " ans
  if [[ "$ans" =~ ^[Yy]$ || -z "$ans" ]]; then
    ensure_env
    for id in $active_nodes; do start_node "$id" || true; done
  fi
}
uninstall_cli() {
  echo -e "\n\ud83d\udea8 Uninstalling Nexus CLI..."
  rm -f "$BIN" /usr/local/bin/nexus-network
  rm -rf /root/nexus-cli
  read -p "Uninstall Rust juga? (y/N): " r
  if [[ "$r" =~ ^[Yy]$ ]]; then rustup self uninstall -y; fi
  echo -e "\n✅ Nexus CLI dihapus.\n"
}

# === Menu actions ===
run_nodes() {
  echo -e "${CYAN}Masukkan satu baris NODE_ID dipisahkan koma/spasi.${RESET}"
  echo -e "Contoh: 7853397, 7853404 7881587"
  read -rp "Enter NODE_ID(s): " RAW

  mapfile -t IDS < <(echo "$RAW" | normalize_ids_from_string)
  if [ "${#IDS[@]}" -eq 0 ]; then echo -e "${RED}NODE_ID kosong.${RESET}"; sleep 2; return; fi

  ensure_env; require_bin; have_screen || { echo "screen not found"; return; }

  local ok=0 skip=0 count=0
  for id in "${IDS[@]}"; do
    if [[ "$id" =~ ^[0-9]+$ ]]; then
      start_node "$id" && ((ok++)) || ((skip++))
      ((count++)); if (( count % 10 == 0 )); then sleep 1; fi
    else
      echo -e "${YELLOW}Lewati ${id}${RESET} (bukan angka)"; ((skip++))
    fi
  done

  echo -e "${GREEN}Selesai.${RESET} Start: $ok, Skip: $skip"
  echo -e "Attach: ${YELLOW}screen -r nexus-<NODE_ID>${RESET}"
  sleep 2
}

run_nodes_from_file() {
  read -rp "File path (default: /root/node_ids.txt): " FILE
  FILE=${FILE:-/root/node_ids.txt}
  if [ ! -f "$FILE" ]; then echo -e "${RED}File tidak ditemukan: $FILE${RESET}"; sleep 2; return; fi

  mapfile -t IDS < <(normalize_ids_from_file "$FILE")
  if [ "${#IDS[@]}" -eq 0 ]; then echo -e "${RED}Tidak ada NODE_ID valid di file.${RESET}"; sleep 2; return; fi

  ensure_env; require_bin; have_screen || { echo "screen not found"; return; }

  echo -e "${YELLOW}Total kandidat:${RESET} ${#IDS[@]}"
  local ok=0 skip=0 count=0
  for id in "${IDS[@]}"; do
    if [[ "$id" =~ ^[0-9]+$ ]]; then
      start_node "$id" && ((ok++)) || ((skip++))
      ((count++)); if (( count % 10 == 0 )); then sleep 1; fi
    else
      echo -e "${YELLOW}Lewati ${id}${RESET} (bukan angka)"; ((skip++))
    fi
  done

  echo -e "${GREEN}Batch selesai.${RESET} Start: $ok, Skip: $skip"
  echo -e "Log dir: ${YELLOW}$LOG_DIR${RESET}"
  sleep 2
}

view_logs() {
  local screens
  screens=$(screen -ls | grep -oE '[0-9]+\.(nexus-[0-9]+)')
  if [ -z "$screens" ]; then
    echo "No active node sessions."
    read -p "Press enter to continue..." _; return
  fi
  echo "Active screen sessions:"; echo "$screens" | nl
  read -rp "Select screen number: " idx
  local selected
  selected=$(echo "$screens" | sed -n "${idx}p")
  screen -r "$selected"
}

stop_all_nodes() {
  for s in $(screen -ls | grep -oE '[0-9]+\.(nexus-[0-9]+)'); do
    screen -S "$s" -X quit || true
  done
  echo -e "${YELLOW}All nodes have been stopped.${RESET}"
  sleep 1
}

# === Menu ===
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
  case "$pilihan" in
    1) install_dependencies; install_nexus_cli; run_nodes ;;
    2) update_cli ;;
    3) view_logs ;;
    4) stop_all_nodes ;;
    5) exit 0 ;;
    6) uninstall_cli ;;
    7) install_dependencies; install_nexus_cli; run_nodes_from_file ;;
    *) echo -e "\e[31mInvalid option.\e[0m"; sleep 2 ;;
  esac
done
