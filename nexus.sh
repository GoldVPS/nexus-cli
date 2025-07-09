#!/bin/bash

# Cek input interaktif
if [ ! -t 0 ]; then
  echo "❌ Script ini tidak mendukung input interaktif via pipe."
  echo "💡 Jalankan dengan: curl -O https://raw.githubusercontent.com/GoldVPS/nexus-cli/main/nexus.sh && bash nexus.sh"
  exit 1
fi

# Input Node ID
echo "🧠 Masukkan satu atau lebih Node ID Nexus (pisahkan dengan spasi):"
read -r -a NODE_IDS

if [ ${#NODE_IDS[@]} -eq 0 ]; then
  echo "❌ Node ID wajib diisi."
  exit 1
fi

# Deteksi Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
echo "📦 Detected Ubuntu $UBUNTU_VERSION"
sleep 1

# Siapkan Docker (jika diperlukan)
if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
  if ! command -v docker &>/dev/null; then
    echo "📦 Docker belum ada, memasang..."
    apt update && apt install -y docker.io
    systemctl enable docker
    systemctl start docker
  fi
fi

# Jalankan untuk tiap Node ID
for NODE_ID in "${NODE_IDS[@]}"; do
  echo ""
  echo "⚙️ Menyiapkan Node ID: $NODE_ID"

  if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    # Versi native (tanpa docker), pakai screen
    screen -S nexus-$NODE_ID -dm bash -c "
      echo '🚀 Menjalankan Nexus CLI untuk Node ID $NODE_ID (tanpa Docker)...'
      curl https://cli.nexus.xyz/ | sh
      sleep 5
      source ~/.bashrc
      nexus-network start --node-id $NODE_ID
      exec bash
    "
    echo "✅ Node $NODE_ID dijalankan di dalam screen."
    echo "🔍 Cek: screen -r nexus-$NODE_ID"

  else
    # Versi docker
    if docker ps -a --format "{{.Names}}" | grep -q "nexus-$NODE_ID"; then
      echo "⚠️ Container nexus-$NODE_ID sudah ada, menghapus..."
      docker rm -f nexus-$NODE_ID
    fi

    echo "🐳 Menjalankan Docker container untuk Node ID $NODE_ID..."

    docker run -dit --name nexus-$NODE_ID ubuntu:24.04

    docker exec nexus-$NODE_ID bash -c "
      apt update && apt install -y curl wget unzip
      curl https://cli.nexus.xyz/ | sh
      sleep 5
      source /root/.profile
      nexus-network start --node-id $NODE_ID
    "

    echo "✅ Node $NODE_ID dijalankan di Docker."
    echo "🔍 Cek: docker logs -f nexus-$NODE_ID"
  fi
done

echo ""
echo "🎉 Semua node telah dijalankan."
