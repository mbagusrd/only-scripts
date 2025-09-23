#!/bin/bash

# Script untuk membuat SSH key dengan algoritma ed25519 dan menambahkan ke config
# Author: Auto-generated script
# Date: $(date +"%Y-%m-%d")

set -e  # Exit on any error

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fungsi untuk print dengan warna
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Fungsi untuk validasi email
validate_email() {
    local email=$1
    if [[ $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Fungsi untuk membuat direktori .ssh jika belum ada
create_ssh_dir() {
    if [ ! -d "$HOME/.ssh" ]; then
        print_info "Membuat direktori ~/.ssh..."
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        print_success "Direktori ~/.ssh berhasil dibuat"
    fi
}

# Fungsi untuk generate SSH key
generate_ssh_key() {
    local key_name=$1
    local email=$2
    local key_path="$HOME/.ssh/$key_name"
    
    print_info "Generating SSH key dengan algoritma ed25519..."
    print_info "Key name: $key_name"
    print_info "Email: $email"
    print_info "Key path: $key_path"
    
    # Generate SSH key
    ssh-keygen -t ed25519 -C "$email" -f "$key_path" -N ""
    
    if [ $? -eq 0 ]; then
        print_success "SSH key berhasil dibuat!"
        print_info "Private key: $key_path"
        print_info "Public key: $key_path.pub"
    else
        print_error "Gagal membuat SSH key"
        exit 1
    fi
}

# Fungsi untuk menambahkan ke SSH config
add_to_ssh_config() {
    local host_alias=$1
    local hostname=$2
    local key_name=$3
    local username=$4
    local config_file="$HOME/.ssh/config"
    
    print_info "Menambahkan konfigurasi ke $config_file..."
    
    # Buat file config jika belum ada
    if [ ! -f "$config_file" ]; then
        touch "$config_file"
        chmod 600 "$config_file"
    fi
    
    # Cek apakah host sudah ada dalam config
    if grep -q "Host $host_alias" "$config_file"; then
        print_warning "Host '$host_alias' sudah ada dalam config. Mengganti dengan konfigurasi baru..."
        # Hapus konfigurasi host yang sudah ada
        sed -i "/^Host $host_alias$/,/^$/d" "$config_file"
    fi
    
    # Tambahkan konfigurasi baru
    cat >> "$config_file" << EOF

Host $host_alias
    HostName $hostname
    User $username
    IdentityFile ~/.ssh/$key_name
    IdentitiesOnly yes
    # AddKeysToAgent yes
EOF
    
    print_success "Konfigurasi berhasil ditambahkan ke SSH config"
}

# Fungsi untuk menampilkan public key
show_public_key() {
    local key_name=$1
    local public_key_path="$HOME/.ssh/$key_name.pub"
    
    print_info "Public key yang dapat Anda copy ke server:"
    echo ""
    echo "================================================"
    cat "$public_key_path"
    echo "================================================"
    echo ""
}

# Fungsi untuk menambahkan key ke SSH agent
add_to_ssh_agent() {
    local key_name=$1
    local key_path="$HOME/.ssh/$key_name"
    
    print_info "Menambahkan key ke SSH agent..."
    
    # Start SSH agent jika belum running
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval "$(ssh-agent -s)"
    fi
    
    # Tambahkan key ke agent
    ssh-add "$key_path"
    
    if [ $? -eq 0 ]; then
        print_success "Key berhasil ditambahkan ke SSH agent"
    else
        print_warning "Gagal menambahkan key ke SSH agent"
    fi
}

# Fungsi utama
main() {
    echo "=============================================="
    echo "    SSH Key Generator dengan Ed25519"
    echo "=============================================="
    echo ""
    
    # Input email
    while true; do
        read -p "Masukkan email Anda: " email
        if validate_email "$email"; then
            break
        else
            print_error "Format email tidak valid. Silakan coba lagi."
        fi
    done
    
    # Input nama key (default: id_ed25519)
    read -p "Masukkan nama key [default: id_ed25519]: " key_name
    key_name=${key_name:-id_ed25519}
    
    # Cek apakah key sudah ada
    if [ -f "$HOME/.ssh/$key_name" ]; then
        print_warning "Key '$key_name' sudah ada!"
        read -p "Apakah Anda ingin menimpa key yang sudah ada? (y/N): " overwrite
        if [[ ! $overwrite =~ ^[Yy]$ ]]; then
            print_info "Operasi dibatalkan."
            exit 0
        fi
    fi
    
    # Tanya apakah ingin membuat config SSH
    read -p "Apakah Anda ingin menambahkan konfigurasi SSH? (Y/n): " add_config
    add_config=${add_config:-Y}
    
    if [[ $add_config =~ ^[Yy]$ ]]; then
        read -p "Masukkan host alias (contoh: github, gitlab, server1): " host_alias
        read -p "Masukkan hostname (contoh: github.com, gitlab.com, 192.168.1.100): " hostname
        read -p "Masukkan username [default: git]: " username
        username=${username:-git}
    fi
    
    echo ""
    print_info "Memulai proses pembuatan SSH key..."
    
    # Buat direktori .ssh
    create_ssh_dir
    
    # Generate SSH key
    generate_ssh_key "$key_name" "$email"
    
    # Tambahkan ke SSH config jika diminta
    if [[ $add_config =~ ^[Yy]$ ]]; then
        add_to_ssh_config "$host_alias" "$hostname" "$key_name" "$username"
    fi
    
    # Tambahkan ke SSH agent
    add_to_ssh_agent "$key_name"
    
    # Tampilkan public key
    show_public_key "$key_name"
    
    echo ""
    print_success "Proses selesai!"
    print_info "Jangan lupa untuk menambahkan public key ke server yang ingin Anda akses."
    
    if [[ $add_config =~ ^[Yy]$ ]]; then
        print_info "Anda sekarang dapat menggunakan: ssh $host_alias"
    fi
}

# Jalankan fungsi utama
main "$@"