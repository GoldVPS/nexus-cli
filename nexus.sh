#!/bin/bash

NODE_ID="$1"

if [ -z "$NODE_ID" ]; then
  echo "❌ Harap jalankan: bash nexus.sh <your-node-id>"
  exit 1
fi

# Deteksi versi Ubuntu
UBUNTU_VERSION=$(lsb_release -rs)

echo "📦 Detected Ubuntu $UBUNTU_VERSION"
sleep 1

# Bikin session screen
echo "🖥 Membuat screen bernama 'nexus'..."
screen -dmS nexus bash -c "

if [ \"$UBUNTU_VERSION\" == \"24.04\" ]; then
    echo '🚀 Installing Nexus CLI for Ubuntu 24.04 (non-docker)...'
    curl https://cli.nexus.xyz/ | sh
    source /root/.bashrc
    nexus-network start --node-id $NODE_ID
else
    echo '🐳 Installing with Docker for Ubuntu < 24.04...'
    # Install Docker jika belum ada
    if ! command -v docker &> /dev/null; then
        echo '📦 Docker belum terinstall, memasang Docker...'
        apt update
        apt install -y docker.io
        systemctl start docker
        systemctl enable docker
    fi

    docker run -it --name nexus-container ubuntu:24.04 bash -c '
        apt update && apt install -y curl wget unzip
        curl https://cli.nexus.xyz/ | sh
        source /root/.profile
        nexus-network start --node-id $NODE_ID
    '
fi
"

echo ""
echo "✅ Proses setup Nexus berjalan di dalam screen 'nexus'"
echo "🔍 Untuk melihat proses: jalankan  screen -r nexus"
