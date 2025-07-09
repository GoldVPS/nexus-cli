#!/bin/bash

if [ ! -t 0 ]; then
  echo "❌ Script ini tidak mendukung input interaktif via pipe."
  echo "💡 Jalankan dengan: curl -O https://raw.githubusercontent.com/GoldVPS/nexus-cli/main/nexus.sh && bash nexus.sh"
  exit 1
fi

echo "🧠 Masukkan satu atau lebih Node ID Nexus (pisahkan dengan spasi):"
read -r -a NODE_IDS

if [ ${#NODE_IDS[@]} -eq 0 ]; then
  echo "❌ Node ID wajib diisi."
  exit 1
fi

UBUNTU_VERSION=$(lsb_release -rs)
echo "📦 Detected Ubuntu $UBUNTU_VERSION"
sleep 1

if [[ "$UBUNTU_VERSION" != "24.04" ]]; then
  if ! command -v docker &>/dev/null; then
    echo "📦 Memasang Docker..."
    apt update && apt install -y docker.io
    systemctl enable docker
    systemctl start docker
  fi
fi

for NODE_ID in "${NODE_IDS[@]}"; do
  echo "⚙️ Menyiapkan Node ID: $NODE_ID"

  SCRIPT_PATH="/root/nexus-$NODE_ID.sh"

  if [[ "$UBUNTU_VERSION" == "24.04" ]]; then
    cat > "$SCRIPT_PATH" <<EOF
#!/bin/bash
echo "🚀 Menjalankan Node ID $NODE_ID tanpa Docker..."
curl https://cli.nexus.xyz/ | sh
sleep 5
source ~/.bashrc
nexus-network start --node-id $NODE_ID
exec bash
EOF

  else
    if docker ps -a --format "{{.Names}}" | grep -q "nexus-$NODE_ID"; then
      echo "⚠️ Menghapus container lama nexus-$NODE_ID"
      docker rm -f nexus-$NODE_ID
    fi

    cat > "$SCRIPT_PATH" <<EOF
#!/bin/bash
echo "🐳 Menjalankan Docker untuk Node ID $NODE_ID..."
docker run -dit --name nexus-$NODE_ID ubuntu:24.04 bash -c '
  apt update && apt install -y curl wget unzip
  curl https://cli.nexus.xyz/ | sh
  sleep 5
  source /root/.profile
  nexus-network start --node-id $NODE_ID
  exec bash
'
sleep 5
docker logs -f nexus-$NODE_ID
EOF

  fi

  chmod +x "$SCRIPT_PATH"
  screen -S nexus-$NODE_ID -dm bash "$SCRIPT_PATH"
  echo "🔹 screen -r nexus-$NODE_ID"
done

echo ""
echo "✅ Semua Node Nexus dijalankan di screen."
