#!/bin/bash

# Script sederhana untuk membuat SSH key ed25519
# Usage: ./simple_ssh_gen.sh [email] [key_name] [host_alias] [hostname]

# Set default values
EMAIL=${1:-"user@example.com"}
KEY_NAME=${2:-"id_ed25519"}
HOST_ALIAS=${3:-"myserver"}
HOSTNAME=${4:-"example.com"}

# Warna output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}SSH Key Generator (Ed25519)${NC}"
echo "=================================="

# Buat direktori .ssh jika belum ada
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key
echo "Generating SSH key..."
ssh-keygen -t ed25519 -C "$EMAIL" -f ~/.ssh/$KEY_NAME -N ""

# Tambahkan ke SSH config
echo "Adding to SSH config..."
cat >> ~/.ssh/config << EOF

Host $HOST_ALIAS
    HostName $HOSTNAME
    User git
    IdentityFile ~/.ssh/$KEY_NAME
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF

chmod 600 ~/.ssh/config

# Start SSH agent dan tambahkan key
eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add ~/.ssh/$KEY_NAME > /dev/null 2>&1

echo -e "${GREEN}✓ SSH key berhasil dibuat!${NC}"
echo ""
echo "Public key:"
echo "==========="
cat ~/.ssh/$KEY_NAME.pub
echo ""
echo "Usage: ssh $HOST_ALIAS"