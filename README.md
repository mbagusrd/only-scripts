# SSH Key Generator Scripts

Script bash untuk membuat SSH key dengan algoritma ed25519 dan menambahkannya secara otomatis ke file SSH config.

## Files

### 1. `generate_ssh_key.sh` (Interactive Version)
Script interaktif lengkap dengan validasi input dan konfigurasi yang detail.

**Fitur:**
- ✅ Validasi email
- ✅ Input interaktif untuk semua parameter
- ✅ Cek dan konfirmasi jika key sudah ada
- ✅ Otomatis membuat direktori `.ssh` jika belum ada
- ✅ Menambahkan key ke SSH agent
- ✅ Menampilkan public key untuk di-copy
- ✅ Konfigurasi SSH config yang lengkap
- ✅ Output berwarna untuk kemudahan pembacaan

**Penggunaan:**
```bash
./generate_ssh_key.sh
```

### 2. `simple_ssh_gen.sh` (Command Line Version)
Script sederhana yang dapat dijalankan dengan parameter atau menggunakan default values.

**Penggunaan:**
```bash
# Dengan parameter
./simple_ssh_gen.sh "your.email@example.com" "my_key" "github" "github.com"

# Menggunakan default values
./simple_ssh_gen.sh
```

**Parameter:**
1. `email` - Email untuk SSH key (default: user@example.com)
2. `key_name` - Nama file key (default: id_ed25519)
3. `host_alias` - Alias untuk SSH config (default: myserver)
4. `hostname` - Hostname server (default: example.com)

## Contoh Penggunaan

### Untuk GitHub:
```bash
./simple_ssh_gen.sh "youremail@gmail.com" "github_key" "github" "github.com"
```

### Untuk GitLab:
```bash
./simple_ssh_gen.sh "youremail@gmail.com" "gitlab_key" "gitlab" "gitlab.com"
```

### Untuk Server Custom:
```bash
./simple_ssh_gen.sh "youremail@gmail.com" "server_key" "myserver" "192.168.1.100"
```

## Output

Kedua script akan:

1. ✅ Membuat SSH key pair (private & public key) dengan algoritma ed25519
2. ✅ Menyimpan key di `~/.ssh/[key_name]`
3. ✅ Menambahkan konfigurasi ke `~/.ssh/config`
4. ✅ Menambahkan key ke SSH agent
5. ✅ Menampilkan public key untuk di-copy ke server

## File SSH Config yang Dihasilkan

```
Host [host_alias]
    HostName [hostname]
    User git
    IdentityFile ~/.ssh/[key_name]
    IdentitiesOnly yes
    AddKeysToAgent yes
```

## Keamanan

- Script menggunakan algoritma **ed25519** yang lebih aman dibanding RSA
- Key dibuat tanpa passphrase untuk kemudahan otomasi
- Permission direktori `.ssh` diset ke `700`
- Permission file config diset ke `600`

## Troubleshooting

### Jika SSH agent tidak berjalan:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/[key_name]
```

### Jika ingin menggunakan key dengan passphrase:
Edit script dan hapus parameter `-N ""` dari perintah `ssh-keygen`

### Untuk melihat key yang sudah ditambahkan ke agent:
```bash
ssh-add -l
```

## Requirements

- Linux/macOS dengan bash
- OpenSSH client (ssh-keygen, ssh-add)
- Permission untuk menulis ke direktori `~/.ssh`