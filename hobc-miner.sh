#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# HOBC Miner untuk Termux (Android ARM64)
# Mining HobbyHash Coin (HOBC) — RandomX CPU — pool resmi
#
#   Pool   : pool.hobbyhashcoin.com:5559 (CPU RandomX, selalu on)
#   Miner  : hobc-rxminer v1.1 (resmi, dari github.com/HobbyHash-Coin-LLC/HobbyHash)
#   PENTING: JANGAN pakai xmrig / miner RandomX lain. Protokol RandomX HOBC
#            itu custom (seed key "HOBCRX01", stratum sendiri) — miner
#            standar TIDAK BISA connect ke pool HOBC.
#
# Cara pakai (di Termux):
#   1. Edit bagian KONFIGURASI di bawah (isi WALLET + daftar WORKERS).
#   2. bash hobc-miner.sh setup    (install tool + build miner dari source)
#   3. bash hobc-miner.sh start    (jalankan semua worker)
#   4. bash hobc-miner.sh status   (cek worker hidup / mati + hashrate)
#   5. bash hobc-miner.sh logs     (lihat log semua worker)
#   6. bash hobc-miner.sh stop     (matikan semua worker)
#
# Catatan jujur:
#   - Pool CPU HOBC itu SOLO: dibayar 45 HOBC HANYA kalau workermu menemukan
#     blok. Share yang diterima cuma bukti miner jalan, bukan pembayaran.
#   - HP (~500 H/s) peluang nemu bloknya kecil — ini seperti lotre.
#   - Mining bikin HP panas + baterai boros. Jangan tinggal mining sambil
#     HP ditutup rapat / di bawah bantal. Istirahatkan HP secara berkala.
# ============================================================================

set -u

# ==================== KONFIGURASI — EDIT DI SINI ====================
# Alamat HOBC kamu (dari wallet Android resmi / web wallet HOBC).
# INI BUKAN alamat wHOBC BSC — yang di-mining itu HOBC native.
WALLET="ALAMAT_HOBC_KAMU"

# Pool resmi CPU RandomX (sudah diverifikasi dari panduan resmi HOBC).
POOL_HOST="pool.hobbyhashcoin.com"
POOL_PORT="5559"

# Daftar worker — format "nama:threads". Satu proses miner per worker.
# Contoh di bawah: 2 worker, masing-masing 2 thread (total 4 thread).
# Aturan praktis:
#   - Total threads JANGAN melebihi jumlah core HP (cek: nproc).
#   - RandomX mode light (dipakai hobc-rxminer) butuh ~256 MB RAM per proses,
#     jadi 2-4 worker masih aman di HP RAM 6-8 GB.
#   - Nama worker bebas, tampil di statistik pool sebagai WALLET.nama.
WORKERS=(
  "hp1:2"
  "hp2:2"
)
# ================== AKHIR KONFIGURASI — JANGAN EDIT ==================

MINER_DIR="$HOME/hobc-miner"
REPO_DIR="$MINER_DIR/HobbyHash"
BIN="$MINER_DIR/hobc-rxminer"
LOG_DIR="$MINER_DIR/logs"
JANSSON_PREFIX="$MINER_DIR/jansson"
REPO_URL="https://github.com/HobbyHash-Coin-LLC/HobbyHash.git"

log() { echo "[hobc-miner] $*"; }
die() { echo "[hobc-miner] ERROR: $*" >&2; exit 1; }

check_arch() {
  local m
  m="$(uname -m)"
  if [ "$m" != "aarch64" ]; then
    log "PERINGATAN: arsitektur terdeteksi '$m', script ini dibuat untuk aarch64 (ARM64)."
    log "Build mungkin tetap jalan, tapi belum teruji di arsitektur ini."
  fi
}

check_wallet() {
  if [ -z "${WALLET:-}" ] || [ "$WALLET" = "ALAMAT_HOBC_KAMU" ]; then
    die "WALLET belum diisi! Edit file ini, isi WALLET dengan alamat HOBC kamu (dari wallet Android resmi / web wallet)."
  fi
}

install_deps() {
  log "Install tool build (git, clang, cmake, make)..."
  pkg update -y || log "pkg update gagal — lanjut, mungkin tool sudah terinstall."
  pkg install -y git clang cmake make || die "pkg install gagal. Cek koneksi internet / storage Termux."
  # jansson (JSON library, dibutuhkan hobc-rxminer).
  if pkg install -y libjansson 2>/dev/null; then
    log "libjansson terinstall dari repo Termux."
  else
    log "libjansson tidak ada di repo — akan di-build dari source saat build miner."
  fi
}

jansson_flags() {
  # Cetak flag compile/link untuk jansson: pakai sistem kalau ada, kalau tidak
  # pakai hasil build lokal di $JANSSON_PREFIX.
  if [ -f /data/data/com.termux/files/usr/include/jansson.h ]; then
    echo "JANSSON_CFLAGS= JANSSON_LIBS=-ljansson"
  elif [ -f "$JANSSON_PREFIX/include/jansson.h" ]; then
    echo "JANSSON_CFLAGS=-I$JANSSON_PREFIX/include JANSSON_LIBS=-L$JANSSON_PREFIX/lib -ljansson"
  else
    echo "JANSSON_CFLAGS= JANSSON_LIBS="
  fi
}

build_jansson_from_source() {
  if [ -f /data/data/com.termux/files/usr/include/jansson.h ]; then return 0; fi
  if [ -f "$JANSSON_PREFIX/include/jansson.h" ]; then return 0; fi
  log "Build jansson dari source..."
  local tmp="$MINER_DIR/build-jansson"
  rm -rf "$tmp"; mkdir -p "$tmp"
  cd "$tmp" || die "tidak bisa masuk $tmp"
  curl -L -o jansson.tar.gz "https://www.digip.org/jansson/releases/jansson-2.14.tar.gz" \
    || die "download jansson gagal — cek internet."
  tar xzf jansson.tar.gz
  cd jansson-2.14 || die "extract jansson gagal"
  cmake -B build -DCMAKE_INSTALL_PREFIX="$JANSSON_PREFIX" -DJANSSON_BUILD_DOCS=OFF \
    || die "cmake jansson gagal"
  cmake --build build -j"$(nproc)" || die "build jansson gagal"
  cmake --install build || die "install jansson gagal"
  log "jansson ter-build di $JANSSON_PREFIX"
}

build_miner() {
  check_arch
  mkdir -p "$MINER_DIR" "$LOG_DIR"
  if [ ! -d "$REPO_DIR/.git" ]; then
    log "Clone repo resmi HobbyHash..."
    git clone --depth 1 "$REPO_URL" "$REPO_DIR" || die "clone repo gagal — cek internet."
  else
    log "Repo sudah ada — pull update terbaru..."
    git -C "$REPO_DIR" pull --ff-only || log "pull gagal, pakai source yang ada."
  fi

  local rx_src="$REPO_DIR/node/AL10/src/crypto/randomx"
  [ -d "$rx_src" ] || die "source RandomX tidak ketemu di $rx_src"
  [ -f "$REPO_DIR/miners/hobc-rxminer/hobc-rxminer.c" ] || die "source miner tidak ketemu"

  build_jansson_from_source
  eval "$(jansson_flags)"

  log "Build librandomx (ini agak lama, 2-5 menit di HP)..."
  local rx_build="$MINER_DIR/build-randomx"
  if ! cmake -S "$rx_src" -B "$rx_build" -DARCH=native -DBUILD_SHARED_LIBS=OFF 2>/dev/null; then
    log "cmake dengan -DARCH=native gagal — coba lagi tanpa flag itu..."
    rm -rf "$rx_build"
    cmake -S "$rx_src" -B "$rx_build" -DBUILD_SHARED_LIBS=OFF \
      || die "cmake librandomx gagal"
  fi
  cmake --build "$rx_build" --target randomx -j"$(nproc)" \
    || die "build librandomx gagal"
  [ -f "$rx_build/librandomx.a" ] || die "librandomx.a tidak terbentuk"

  log "Compile hobc-rxminer..."
  local cc="${CC:-cc}"
  # File .c HARUS dikompilasi sebagai C (bukan C++): di C++, calloc/memchr
  # mengembalikan void* yang tidak bisa langsung jadi pointer bertipe
  # (error di hobc-rxminer.c baris 440/441/455). Link tetap pakai driver
  # C++ (c++) supaya runtime C++ (libc++) ikut ke-link.
  "$cc" -O2 -pthread \
    -I"$rx_src/src" \
    $JANSSON_CFLAGS \
    -c "$REPO_DIR/miners/hobc-rxminer/hobc-rxminer.c" \
    -o "$rx_build/hobc-rxminer.o" || die "compile hobc-rxminer gagal"
  c++ -O2 -pthread \
    "$rx_build/hobc-rxminer.o" \
    "$rx_build/librandomx.a" \
    $JANSSON_LIBS -lm \
    -o "$BIN" || die "link hobc-rxminer gagal"
  chmod +x "$BIN"
  log "Miner berhasil di-build: $BIN"
  "$BIN" 2>&1 | head -5 || true
}

check_pool() {
  log "Tes koneksi ke $POOL_HOST:$POOL_PORT ..."
  if timeout 8 bash -c "cat < /dev/null > /dev/tcp/$POOL_HOST/$POOL_PORT" 2>/dev/null; then
    log "Pool BISA dijangkau."
  else
    log "PERINGATAN: pool TIDAK bisa dijangkau sekarang (timeout / offline)."
    log "Cek status pool di https://hobbyhashcoin.com/pool/cpu/ sebelum mining."
  fi
}

worker_pids() {
  # Cetak pid worker dari file pid (kalau prosesnya masih hidup).
  local name pid
  for f in "$LOG_DIR"/*.pid; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .pid)"
    pid="$(cat "$f")"
    if kill -0 "$pid" 2>/dev/null; then echo "$name $pid"; fi
  done
}

cmd_start() {
  check_wallet
  [ -x "$BIN" ] || die "miner belum ada — jalankan dulu: bash hobc-miner.sh setup"
  mkdir -p "$LOG_DIR"
  check_pool
  local w name threads pid
  for w in "${WORKERS[@]}"; do
    IFS=':' read -r name threads <<< "$w"
    [ -n "$name" ] && [ -n "$threads" ] || die "format WORKERS salah: '$w' (harus nama:threads)"
    if [ -f "$LOG_DIR/$name.pid" ] && kill -0 "$(cat "$LOG_DIR/$name.pid")" 2>/dev/null; then
      log "worker $name sudah jalan (pid $(cat "$LOG_DIR/$name.pid")) — lewati."
      continue
    fi
    log "Start worker $name ($threads thread) -> $WALLET.$name ..."
    {
      echo "=== start $(date '+%Y-%m-%d %H:%M:%S') — $WALLET.$name ($threads thread) ==="
    } >> "$LOG_DIR/$name.log"
    nohup "$BIN" -o "$POOL_HOST:$POOL_PORT" -u "$WALLET" -w "$name" -t "$threads" \
      >> "$LOG_DIR/$name.log" 2>&1 &
    pid=$!
    echo "$pid" > "$LOG_DIR/$name.pid"
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
      log "worker $name jalan (pid $pid), log: $LOG_DIR/$name.log"
    else
      log "worker $name MATI dalam 2 detik — cek log: tail $LOG_DIR/$name.log"
    fi
  done
  log "Selesai. Cek status: bash hobc-miner.sh status"
}

cmd_stop() {
  local name pid stopped=0
  for f in "$LOG_DIR"/*.pid; do
    [ -f "$f" ] || continue
    name="$(basename "$f" .pid)"
    pid="$(cat "$f")"
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" && log "worker $name (pid $pid) dimatikan." && stopped=$((stopped + 1))
    fi
    rm -f "$f"
  done
  # Bersihkan sisa proses hobc-rxminer yang pid-file-nya hilang.
  pkill -f hobc-rxminer 2>/dev/null && log "sisa proses hobc-rxminer dibersihkan."
  [ "$stopped" -eq 0 ] && log "tidak ada worker yang sedang jalan."
}

cmd_status() {
  local found=0
  while read -r name pid; do
    found=1
    local hr
    hr="$(grep -aoE "[0-9]+(\.[0-9]+)? H/s" "$LOG_DIR/$name.log" 2>/dev/null | tail -1)"
    echo "worker $name : JALAN (pid $pid) ${hr:+— hashrate terakhir: $hr}"
  done < <(worker_pids)
  if [ "$found" -eq 0 ]; then
    echo "tidak ada worker yang jalan. Start dengan: bash hobc-miner.sh start"
  fi
  echo "--- 5 baris log terakhir per worker ---"
  for f in "$LOG_DIR"/*.log; do
    [ -f "$f" ] || continue
    echo "== $(basename "$f") =="
    tail -5 "$f"
  done
}

cmd_logs() {
  if [ "${1:-}" != "" ]; then
    tail -f "$LOG_DIR/$1.log"
  else
    tail -f "$LOG_DIR"/*.log
  fi
}

usage() {
  echo "Pakai: bash hobc-miner.sh {setup|start|stop|restart|status|logs [nama-worker]|check}"
  echo "  setup   : install tool + build hobc-rxminer dari source resmi"
  echo "  start   : jalankan semua worker di WORKERS (bisa diulang, yang sudah jalan dilewati)"
  echo "  stop    : matikan semua worker"
  echo "  restart : stop lalu start lagi"
  echo "  status  : cek worker hidup/mati + hashrate terakhir + log singkat"
  echo "  logs    : ikuti log semua worker (atau satu worker: logs hp1)"
  echo "  check   : tes koneksi ke pool saja"
}

case "${1:-}" in
  setup)   install_deps; build_miner ;;
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_stop; sleep 2; cmd_start ;;
  status)  cmd_status ;;
  logs)    cmd_logs "${2:-}" ;;
  check)   check_pool ;;
  *)       usage ;;
esac
