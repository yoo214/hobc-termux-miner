# HOBC Miner untuk Termux (Android)

Mining **HobbyHash Coin (HOBC)** di HP Android pakai Termux — RandomX CPU, pool resmi, banyak worker yang diatur manual lewat script.

> **Jujur dulu:** pool CPU HOBC itu **solo** — dibayar 45 HOBC **hanya kalau workermu menemukan blok**. Share yang diterima cuma bukti miner jalan, bukan pembayaran. HP (~500 H/s) peluang nemu bloknya kecil, ini seperti lotre. Jangan berharap penghasilan harian pasti.

## Yang kamu butuhkan

- HP Android ARM64 + aplikasi **Termux** (install dari F-Droid, bukan Play Store)
- **Alamat HOBC** — dari wallet Android resmi HOBC (https://hobbyhashcoin.com/downloads/#android-wallet) atau web wallet HOBC. Ini **bukan** alamat wHOBC BSC.
- Internet + sedikit sabar saat pertama kali build (5–10 menit di HP)

## Cara pakai

```bash
# 1. Masuk Termux, download script ini
pkg install -y git
git clone https://github.com/yoo214/hobc-termux-miner.git
cd hobc-termux-miner

# 2. Edit konfigurasi (WALLET + WORKERS) — pakai nano atau editor apa saja
nano hobc-miner.sh

# 3. Setup sekali saja (install tool + build miner resmi dari source)
bash hobc-miner.sh setup

# 4. Jalankan semua worker
bash hobc-miner.sh start

# 5. Cek status / log
bash hobc-miner.sh status
bash hobc-miner.sh logs

# 6. Berhenti
bash hobc-miner.sh stop
```

## Konfigurasi (di dalam `hobc-miner.sh`)

```bash
WALLET="ALAMAT_HOBC_KAMU"   # <-- WAJIB diisi alamat HOBC kamu

WORKERS=(
  "hp1:2"   # worker "hp1", 2 thread
  "hp2:2"   # worker "hp2", 2 thread
)
```

- Format worker: `"nama:threads"` — satu proses miner per worker.
- Total threads jangan melebihi jumlah core HP (cek dengan `nproc`).
- Nama worker tampil di statistik pool sebagai `ALAMAT.nama`.

Perintah lain: `restart`, `logs hp1` (log satu worker), `check` (tes koneksi ke pool saja).

## Cara cek hasil mining

Buka https://hobbyhashcoin.com/pool/cpu/ lalu tempel alamat HOBC kamu di kolom payout address — kelihatan share, worker, dan blok yang ditemukan.

Status pool saat script ini dibuat (24 Nov 2026, dicek langsung): **Online**, 8 worker, hashrate 16,18 KH/s, 13.900.590 share diterima, 0 ditolak.

## Kenapa bukan xmrig?

Protokol RandomX HOBC itu custom (seed key `HOBCRX01`, stratum sendiri) — **miner RandomX standar seperti xmrig TIDAK BISA connect ke pool HOBC**. Script ini build `hobc-rxminer` v1.1 resmi dari source (github.com/HobbyHash-Coin-LLC/HobbyHash).

## Jual hasil mining

Yang di-mining itu **HOBC native** (koin L1, tidak punya contract address — seperti BTC). Yang bisa dijual di PancakeSwap itu versi wrap-nya:

- **wHOBC (BSC, BEP-20):** `0x8eC9d91c4B30686Bc5D97B72E1BefEf1566FD878`
  - Pair PancakeSwap V2: `0x75c43f85a655779D6057d3fA90Cca7e3AAfF0a96` (wHOBC/USDT)
  - Harga ~$0,000172, likuiditas cuma ~$242 (24 Nov 2026) — **jualnya susah, jual beberapa dolar saja bisa anjlokin harga**
  - Cek di BscScan: https://bscscan.com/address/0x8eC9d91c4B30686Bc5D97B72E1BefEf1566FD878
- HOBC native di-wrap 1:1 jadi wHOBC lewat bridge resmi HOBC, baru bisa dijual di PancakeSwap.

## Keamanan

- Script ini **tidak pernah minta seed phrase / private key**. Jangan pernah masukkan seed ke script apa pun.
- Script ini cuma butuh alamat HOBC publik (untuk terima payout) — alamat itu aman dibagikan.
- Mining bikin HP panas dan boros baterai. Jangan mining sambil HP ditutup rapat / di bawah bantal, dan istirahatkan HP berkala.
- Repo ini publik dan scriptnya bisa dibaca siapa saja — silakan audit sendiri sebelum jalan.
