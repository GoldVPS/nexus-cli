#!/bin/bash
set -e

# ====== Config ======
LOG_DIR="/root/nexus_logs"
DB_FILE="/root/nexus_nodes.db"          # daftar target node id (satu per baris, unik)
BIN="/usr/local/bin/nexus"              # path absolut nexus
SELF_INSTALL_PATH="/usr/local/sbin/nexus-manager.sh"  # path script utk systemd

# ====== Colors ======
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; RESET='\033[0m'

# ====== Header ======
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

# ====== Utils ======
ensure_dirs() { mkdir -p "$LOG_DIR"; touch "$DB_FILE"; sort -u -o "$DB_FILE" "$DB_FILE"; }
require_bin() {
  if ! [ -x "$BIN" ]; then
    echo -e "${RED}Binary tidak ditemukan: $BIN${RESET}"
    return 1
  fi
}

normalize_ids_from_string() {
  # STDIN -> tokens unik per baris
  tr ',;' ' ' | tr -s ' ' | sed 's/^ *//;s/ *$//' | awk '{for(i=1;i<=NF;i++) print $i}' | sed '/^$/d' | sort -u
}
normalize_ids_from_file() {
  local file="$1"
  sed 's/#.*$//' "$file" | tr ',;' ' ' | tr '\n' ' ' | tr -s ' ' | sed 's/^ *//;s/ *$//' \
    | awk '{for(i=1;i<=NF;i++) print $i}' | sed '/^$/d' | sort -u
}
add_ids_to_db() {
  # args: list id
  touch "$DB_FILE"
  (cat "$DB_FILE"; printf "%s\n" "$@") | sed '/^$/d' | sort -u > "${DB_FILE}.tmp"
  mv "${DB_FILE}.tmp" "$DB_FILE"
}

# ====== Start/Stop ======
start_node() {
  local id="$1"
  local sess="nexus-$id"
  require_bin || return 1

  # sudah ada?
  if screen -ls | awk '{print $1}' | grep -qxE '[0-9]+\.'"$sess" ; then
    echo -e "${YELLOW}Lewati ${id}${RESET} (sudah berjalan)"
    return 1
  fi

  # start pakai login shell agar PATH/env benar
  screen -dmS "$sess" bash -lc "
    ulimit -n 65535 || true
    exec $BIN start --node-id $id >>'$LOG_DIR/nexus_${id}.log' 2>&1
  "

  sleep 0.25
  if ! screen -ls | awk '{print $1}' | grep -qxE '[0-9]+\.'"$sess" ; then
    echo -e "${RED}Gagal membuat screen untuk ${id}${RESET}"
    echo '[start_node] screen create failed' >>"$LOG_DIR/nexus_${id}.log"
    return 1
  fi

  echo -e "${GREEN}Start node ${id}${RESET} → log: ${YELLOW}$LOG_DIR/nexus_${id}.log${RESET}"
  sleep 0.15
  return 0
}

stop_all_nodes() {
  for s in $(screen -ls | grep nexus- | awk '{print $1}'); do
    screen -S "$s" -X quit || true
  done
  echo -e "${YELLOW}All nodes have been stopped.${RESET}"
}

# ====== Install/Update CLI ======
install_dependencies() {
  echo -e "${YELLOW}Checking dependencies...${RESET}"
  apt update
  apt install -y curl screen git build-essential pkg-config libssl-dev libclang-dev cmake
  ensure_dirs
}
install_nexus_cli() {
  if [ -x "$BIN" ]; then
    echo -e "${GREEN}Nexus CLI already installed.${RESET}"; return
  fi
  echo -e "${YELLOW}Installing Nexus CLI from source...${RESET}"
  if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
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
  active_nodes=$(screen -ls | grep nexus- | awk -F'nexus-' '{print $2}' | awk '{print $1}')
  rm -rf ~/.nexus; sed -i '/.nexus\/bin/d' ~/.bashrc || true
  if ! command -v cargo >/dev/null 2>&1; then
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source "$HOME/.cargo/env"
  fi
  apt install -y build-essential pkg-config libssl-dev libclang-dev cmake
  stop_all_nodes; pkill -f "nexus start" 2>/dev/null || true
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
    ensure_dirs
    for id in $active_nodes; do start_node "$id" || true; done
  fi
}

# ====== Input Handlers ======
run_nodes() {
  echo -e "${CYAN}Masukkan NODE_ID dipisahkan koma/spasi (contoh: 7853397, 7853404 7881587)${RESET}"
  read -rp "Enter NODE_ID(s): " RAW
  mapfile -t IDS < <(echo "$RAW" | normalize_ids_from_string)
  if [ "${#IDS[@]}" -eq 0 ]; then echo -e "${RED}NODE_ID kosong.${RESET}"; sleep 2; return; fi
  ensure_dirs
  local ok=0 skip=0 count=0
  for id in "${IDS[@]}"; do
    if [[ "$id" =~ ^[0-9]+$ ]]; then
      start_node "$id" && ((ok++)) || ((skip++))
      ((count++)); if (( count % 10 == 0 )); then sleep 1; fi
    else
      echo -e "${YELLOW}Lewati ${id}${RESET} (bukan angka)"; ((skip++))
    fi
  done
  add_ids_to_db "${IDS[@]}"
  echo -e "${GREEN}Selesai.${RESET} Start: $ok, Skip: $skip"
  echo -e "Attach: ${YELLOW}screen -r nexus-<ID>${RESET}"
  sleep 2
}
run_nodes_from_file() {
  read -rp "File path (default: /root/node_ids.txt): " FILE
  FILE=${FILE:-/root/node_ids.txt}
  if [ ! -f "$FILE" ]; then echo -e "${RED}File tidak ditemukan: $FILE${RESET}"; sleep 2; return; fi
  mapfile -t IDS < <(normalize_ids_from_file "$FILE")
  if [ "${#IDS[@]}" -eq 0 ]; then echo -e "${RED}Tidak ada ID valid.${RESET}"; sleep 2; return; fi
  ensure_dirs
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
  add_ids_to_db "${IDS[@]}"
  echo -e "${GREEN}Batch selesai.${RESET} Start: $ok, Skip: $skip"
  echo -e "Log dir: ${YELLOW}$LOG_DIR${RESET}"
  sleep 2
}

# ====== Watchdog (Auto-Restart) ======
watchdog_loop() {
  ensure_dirs
  echo "[watchdog] starting..."
  require_bin || { echo "[watchdog] $BIN not found"; exit 1; }
  while true; do
    # baca daftar target dari DB
    if [ -s "$DB_FILE" ]; then
      while IFS= read -r id; do
        [[ "$id" =~ ^[0-9]+$ ]] || continue
        # kalau screen belum ada → restart
        if ! screen -ls | awk '{print $1}' | grep -qxE '[0-9]+\.'nexus-"$id"; then
          echo "[watchdog] restarting $id"
          start_node "$id" || true
        fi
      done < <(sort -u "$DB_FILE")
    fi
    sleep 30
  done
}

install_watchdog_service() {
  ensure_dirs
  # pastikan script berada di SELF_INSTALL_PATH untuk systemd
  if [ "$0" != "$SELF_INSTALL_PATH" ]; then
    cp "$0" "$SELF_INSTALL_PATH"
    chmod +x "$SELF_INSTALL_PATH"
  fi

  cat >/etc/systemd/system/nexus-watchdog.service <<EOF
[Unit]
Description=Nexus Nodes Watchdog (auto-restart)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $SELF_INSTALL_PATH --watchdog
Restart=always
RestartSec=5
User=root
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now nexus-watchdog.service
  systemctl status --no-pager --lines=3 nexus-watchdog.service || true
  echo -e "${GREEN}✅ Auto-restart diaktifkan (service: nexus-watchdog).${RESET}"
}
disable_watchdog_service() {
  systemctl disable --now nexus-watchdog.service 2>/dev/null || true
  echo -e "${YELLOW}Auto-restart dimatikan.${RESET}"
}
status_watchdog_service() {
  systemctl status --no-pager --lines=20 nexus-watchdog.service 2>/dev/null || echo "Service tidak ada."
}

# ====== Uninstall CLI ======
uninstall_cli() {
  echo -e "\n\ud83d\udea8 Uninstalling Nexus CLI..."
  rm -f "$BIN" /usr/local/bin/nexus-network
  rm -rf /root/nexus-cli
  read -p "Uninstall Rust juga? (y/N): " r
  if [[ "$r" =~ ^[Yy]$ ]]; then rustup self uninstall -y; fi
  echo -e "\n✅ Nexus CLI dihapus.\n"
}

# ====== Menu ======
menu() {
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
    echo -e "  \e[1;32m8.\e[0m Enable Auto-Restart (watchdog)"
    echo -e "  \e[1;32m9.\e[0m Disable Auto-Restart"
    echo -e "  \e[1;32m10.\e[0m Watchdog status"
    echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
    echo -ne "\n\e[1;36mSelect an option (1-10): \e[0m"; read -r pilihan

    case $pilihan in
      1) install_dependencies; install_nexus_cli; run_nodes ;;
      2) update_cli ;;
      3)
         local screens=$(screen -ls | grep nexus- | awk '{print $1}')
         if [ -z "$screens" ]; then echo "No active node sessions."; read -p "Enter to continue..." _; continue; fi
         echo "Active screen sessions:"; echo "$screens" | nl
         read -rp "Select screen number: " idx
         selected=$(echo "$screens" | sed -n "${idx}p"); screen -r "${selected}"
         ;;
      4) stop_all_nodes ;;
      5) exit 0 ;;
      6) uninstall_cli ;;
      7) install_dependencies; install_nexus_cli; run_nodes_from_file ;;
      8) install_watchdog_service; read -p "Enter to continue..." _ ;;
      9) disable_watchdog_service; sleep 1 ;;
      10) status_watchdog_service; read -p "Enter to continue..." _ ;;
      *) echo -e "\e[31mInvalid option.\e[0m"; sleep 2 ;;
    esac
  done
}

# ====== Entrypoints ======
if [[ "$1" == "--watchdog" ]]; then
  watchdog_loop
else
  menu
fi
