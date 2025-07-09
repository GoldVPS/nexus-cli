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

# Loop tiap node
for NODE_ID in "${NODE_IDS[@]}"; do
  echo "⚙️ Menyiapkan Node ID: $NODE_ID"

  screen -dmS nexus-$NODE_ID bash -c "
  if [ \"$UBUNTU_VERSION\" == \"24.04\" ]; then
      echo '🚀 Install Nexus CLI di Ubuntu 24.04 (tanpa Docker)...'
      curl https://cli.nexus.xyz/ | sh
      source /root/.bashrc
      nexus-network start --node-id $NODE_ID
  else
      echo '🐳 Jalankan Docker untuk Ubuntu < 24.04...'
      if ! command -v docker &>/dev/null; then
          echo '📦 Docker belum ada, install dulu...'
          apt update && apt install -y docker.io
          systemctl start docker
          systemctl enable docker
      fi

      docker run -dit --name nexus-$NODE_ID ubuntu:24.04 bash -c '
          apt update && apt install -y curl wget unzip
          curl https://cli.nexus.xyz/ | sh
          source /root/.profile
          nexus-network start --node-id $NODE_ID
      '
  fi
  "
done

# Info selesai
echo ""
echo "✅ Semua Node Nexus sedang dijalankan:"
for NODE_ID in "${NODE_IDS[@]}"; do
  echo "🔹 screen -r nexus-$NODE_ID"
done
