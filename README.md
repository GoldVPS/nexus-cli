
# Nexus CLI Node Launcher (Ubuntu 24.04)

A custom script to manage your **Nexus CLI Node** with ease — no Docker required. Built specifically for **Ubuntu 24.04 LTS**.

**Need powerful VPS with NVMe + affordable prices?**
**Order now:** https://goldvps.net
## 📦 Features

- Automatic Nexus CLI installation
- Run multiple nodes via `screen`
- Easily update the CLI
- View individual node logs
- Stop all active nodes at once

---

## ⚙️ Quick Start

Run the following commands:

```bash
curl -O https://raw.githubusercontent.com/GoldVPS/nexus-cli/main/nexus-ubuntu24.sh
bash nexus-ubuntu24.sh
```

---

## 📋 Main Menu

```
1. Add & Run Node
2. Update Nexus CLI
3. View Node Logs (screen)
4. Stop All Nodes
5. Exit
```

---
⚠️ Issue

If you are facing this issue:

Do you agree to the Nexus Beta Terms of Use (https://nexus.xyz/terms-of-use)? (Y/n) Y

Could not find a precompiled binary for linux-x86_64  
Please build from source:  
git clone https://github.com/nexus-xyz/nexus-cli.git  
cd nexus-cli/clients/cli  
cargo build --release

👉 Please Choose Update Nexus CLI before Add & Run Nexus CLI

---
## 🔁 Update Nexus CLI

This script removes the existing `.nexus` directory and reinstalls the Nexus CLI from the official source.

---

## 📄 Node Logs

All nodes run in `screen` sessions. You can manually check logs via:

```bash
screen -ls
screen -r nexus-<NODE_ID>
```

Or use option 3 in the menu.

---

## 📌 Notes

- Script designed for Ubuntu 24.04 only
- No Docker — lightweight and simple
- Perfect for running multiple nodes on a single server

---

## MADE BY [GOLDVPS](https://goldvps.net)
Created by: https://t.me/miftaikyy
Also founder of [GOLDVPS](https://goldvps.net)

Need powerful VPS with NVMe + affordable prices?  
Order now: https://goldvps.net
