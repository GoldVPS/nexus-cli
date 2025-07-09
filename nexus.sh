#!/bin/bash

# Cek apakah dijalankan langsung di shell
if [ ! -t 0 ]; then
  echo "❌ Script ini tidak mendukung input interaktif jika dijalankan via pipe (|)."
  echo "💡 Gunakan: curl -O https://raw.githubusercontent.com/GoldVPS/nexus-cli/main/nexus.sh && bash nexus.sh"
  exit 1
fi

# Input Node ID manual
echo "🧠 Masukkan satu atau lebih Node ID Nexus (pisahkan dengan spasi):"
read -r -a NODE_IDS

if [ ${#NODE_IDS[@]} -eq 0 ]; then
  echo "❌ Node ID wajib diisi."
  exit 1
fi

# Deteksi versi Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)
echo "📦 Detected Ubuntu $UBUNTU_VERSION"
sleep 1

# Install Docker jika butuh (untuk Ubuntu < 24.04)
if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
  if ! command -v docker &>/dev/null; then
    echo "📦 Docker belum ada, memasang Docker..."
    apt update && apt install -y docker.io
    systemctl start docker
    systemctl enable docker
  fi
fi

# Loop tiap node
for NODE_ID in "${NODE_IDS[@]}"; do
  echo "⚙️ Menyiapkan Node ID: $NODE_ID"

  # Hapus container jika sudah ada
  if docker ps -a --format "{{.Names}}" | grep -q "nexus-$NODE_ID"; then
    echo "⚠️ Container nexus-$NODE_ID sudah ada, menghapus..."
    docker rm -f nexus-$NODE_ID
  fi

  # Jalankan semuanya di dalam screen
  screen -S nexus-$NODE_ID -dm bash -c "
    if [ \"$UBUNTU_VERSION\" == \"24.04\" ]; then
      echo '🚀 Install Nexus CLI di Ubuntu 24.04 (tanpa Docker)...'
      curl https://cli.nexus.xyz/ | sh
      sleep 5
      source ~/.bashrc
      nexus-network start --node-id $NODE_ID
      exec bash
    else
      echo '🐳 Menjalankan Docker container untuk Node ID: $NODE_ID'
      docker run -dit --name nexus-$NODE_ID ubuntu:24.04 bash -c '
        apt update && apt install -y curl wget unzip
        curl https://cli.nexus.xyz/ | sh
        sleep 5
        source /root/.profile
        nexus-network start --node-id $NODE_ID
        exec bash
      '

      echo ''
      echo '📺 Monitoring log Docker...'
      echo '----------------------------'
      docker logs -f nexus-$NODE_ID
    fi
  "

  echo "🔹 screen -r nexus-$NODE_ID"
done

# Info akhir
echo ""
echo "✅ Semua Node Nexus telah dijalankan di dalam screen."
