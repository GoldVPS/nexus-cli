#!/bin/bash

# Cek apakah dijalankan langsung
if [ ! -t 0 ]; then
  echo "❌ Script ini tidak mendukung input interaktif via pipe."
  echo "💡 Jalankan: curl -O https://raw.githubusercontent.com/GoldVPS/nexus-cli/main/nexus.sh && bash nexus.sh"
  exit 1
fi

# Input node ID
echo "🧠 Masukkan satu atau lebih Node ID Nexus (pisahkan dengan spasi):"
read -r -a NODE_IDS

if [ ${#NODE_IDS[@]} -eq 0 ]; then
  echo "❌ Node ID wajib diisi."
  exit 1
fi

# Deteksi Ubuntu version
UBUNTU_VERSION=$(lsb_release -rs)
echo "📦 Detected Ubuntu $UBUNTU_VERSION"
sleep 1

# Install Docker jika dibutuhkan
if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
  if ! command -v docker &>/dev/null; then
    echo "📦 Docker belum ada, memasang..."
    apt update && apt install -y docker.io
    systemctl enable docker
    systemctl start docker
  fi
fi

# Loop per node ID
for NODE_ID in "${NODE_IDS[@]}"; do
  echo ""
  echo "⚙️ Menyiapkan Node ID: $NODE_ID"

  if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    # Native install (Ubuntu 24.04)
    screen -S nexus-$NODE_ID -dm bash -c "
      echo '🚀 Menjalankan Nexus CLI native...'
      curl https://cli.nexus.xyz/ | sh
      echo 'export PATH=\$HOME/.nexus/bin:\$PATH' >> ~/.bashrc
      export PATH=\$HOME/.nexus/bin:\$PATH
      sleep 3
      nexus-network start --node-id $NODE_ID
      exec bash
    "
    echo "✅ Node $NODE_ID dijalankan di dalam screen."
    echo "🔍 Cek: screen -r nexus-$NODE_ID"

  else
    # Jalankan pakai Docker
    if docker ps -a --format '{{.Names}}' | grep -q "nexus-$NODE_ID"; then
      echo "⚠️ Container nexus-$NODE_ID sudah ada, menghapus dulu..."
      docker rm -f nexus-$NODE_ID
    fi

    echo "🐳 Menjalankan Docker container Nexus..."

    docker run -dit \
      --name nexus-$NODE_ID \
      --privileged \
      --network host \
      --cap-add=ALL \
      ubuntu:24.04

    docker exec nexus-$NODE_ID bash -c '
      apt update && apt install -y curl wget unzip net-tools iproute2 procps
      curl https://cli.nexus.xyz/ | sh
      echo "export PATH=\$HOME/.nexus/bin:\$PATH" >> ~/.bashrc
      export PATH=$HOME/.nexus/bin:$PATH
      sleep 3
      nexus-network start --node-id '"$NODE_ID"'
    '

    echo "✅ Node $NODE_ID dijalankan di Docker."
    echo "🔍 Cek log: docker logs -f nexus-$NODE_ID"
  fi
done

echo ""
echo "🎉 Semua node telah dijalankan."
