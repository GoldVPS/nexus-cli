#!/bin/bash
set -e

# === Konfigurasi dasar ===
BASE_CONTAINER_NAME="nexus-node"
IMAGE_NAME="nexus-node:latest"
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
    echo -e "           Nexus CLI Node Manager"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# === Cek versi Ubuntu ===
function get_ubuntu_version() {
    lsb_release -rs | cut -d. -f1
}

# === Periksa Docker ===
function check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${YELLOW}Docker tidak ditemukan. Menginstal Docker...${RESET}"
        apt update
        apt install -y docker.io
        systemctl enable docker
        systemctl start docker
    fi
}

# === Build Docker Image ===
function build_image() {
    WORKDIR=$(mktemp -d)
    cd "$WORKDIR"

    cat > Dockerfile <<EOF
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
ENV PROVER_ID_FILE=/root/.nexus/node-id
RUN apt-get update && apt-get install -y curl screen bash net-tools iproute2 procps \
    && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EOF

    cat > entrypoint.sh <<EOF
#!/bin/bash
set -e
if [ -z "\$NODE_ID" ]; then
    echo "NODE_ID belum disetel"
    exit 1
fi
mkdir -p /root/.nexus
echo "\$NODE_ID" > /root/.nexus/node-id
exec nexus-network start --node-id "\$NODE_ID"
EOF

    docker build -t "$IMAGE_NAME" .
    cd -
    rm -rf "$WORKDIR"
}

# === Jalankan node secara native ===
function run_native_node() {
    local node_id=$1
    local screen_name="nexus-${node_id}"
    screen -dmS "$screen_name" bash -c "curl -sSL https://cli.nexus.xyz/ | sh && export PATH=\$HOME/.nexus/bin:\$PATH && sleep 5 && nexus-network start --node-id $node_id && exec bash"
    echo -e "${GREEN}Node $node_id dijalankan di screen: screen -r $screen_name${RESET}"
}

# === Jalankan Container ===
function run_container_node() {
    local node_id=$1
    local container_name="${BASE_CONTAINER_NAME}-${node_id}"

    docker rm -f "$container_name" 2>/dev/null || true
    docker run -d --name "$container_name" \
        --privileged --network host --cap-add=ALL \
        -e NODE_ID="$node_id" "$IMAGE_NAME"
}

# === Get all node IDs ===
function get_all_nodes() {
    docker ps -a --format "{{.Names}}" | grep "^${BASE_CONTAINER_NAME}-" | sed "s/${BASE_CONTAINER_NAME}-//"
}

# === Show node status ===
function list_nodes() {
    show_header
    echo -e "${CYAN}📊 Daftar Node Terdaftar:${RESET}"
    local all_nodes=($(get_all_nodes))
    for i in "${!all_nodes[@]}"; do
        local node_id=${all_nodes[$i]}
        local container="${BASE_CONTAINER_NAME}-${node_id}"
        local status=$(docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        echo "$((i+1)). Node ID: $node_id | Status: $status"
    done
    read -p "Tekan enter untuk kembali..." dummy
}

# === Lihat log ===
function view_logs() {
    local all_nodes=($(get_all_nodes))
    echo "Pilih node untuk lihat log:"
    for i in "${!all_nodes[@]}"; do
        echo "$((i+1)). ${all_nodes[$i]}"
    done
    read -rp "Nomor: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#all_nodes[@]} )); then
        local selected=${all_nodes[$((choice-1))]}
        docker logs -f "${BASE_CONTAINER_NAME}-${selected}"
    fi
}

# === Hapus Node ===
function uninstall_node() {
    local node_id=$1
    docker rm -f "${BASE_CONTAINER_NAME}-${node_id}" 2>/dev/null || true
    echo -e "${YELLOW}Node $node_id telah dihapus.${RESET}"
}

# === Hapus Semua Node ===
function uninstall_all_nodes() {
    local all_nodes=($(get_all_nodes))
    for node in "${all_nodes[@]}"; do
        uninstall_node "$node"
    done
    echo "${YELLOW}Semua node dihapus.${RESET}"
    read -p "Tekan enter..." dummy
}

# === Update Semua Node ===
function update_all_nodes() {
    echo -e "${YELLOW}⏳ Update semua node...${RESET}"
    build_image
    local all_nodes=($(get_all_nodes))
    for node_id in "${all_nodes[@]}"; do
        run_container_node "$node_id"
    done
    echo -e "${GREEN}✔ Semua node berhasil di-update.${RESET}"
    read -p "Tekan enter..." dummy
}

# === Tambah & jalankan node ===
function add_node() {
    check_docker
    local version=$(get_ubuntu_version)
    read -rp "Masukkan satu atau lebih NODE_ID (pisahkan spasi): " input
    [ -z "$input" ] && echo "NODE_ID wajib diisi." && sleep 2 && return
    build_image
    for id in $input; do
        if [[ "$version" == "24" ]]; then
            run_native_node "$id"
        else
            run_container_node "$id"
        fi
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
    echo -e "${GREEN} 5.${RESET} 🔄 Update Semua Node"
    echo -e "${GREEN} 6.${RESET} 🚪 Keluar"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    read -rp "Pilih menu (1-6): " pilihan
    case $pilihan in
        1) add_node ;;
        2) list_nodes ;;
        3) view_logs ;;
        4) uninstall_all_nodes ;;
        5) update_all_nodes ;;
        6) exit 0 ;;
        *) echo "Pilihan tidak valid."; sleep 2 ;;
    esac
done
