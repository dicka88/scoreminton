# PRD — Scoreminton

Papan skor badminton berbasis web, mobile-first (HP & tablet), orientasi landscape diutamakan.

| | |
|---|---|
| Versi | 1.0 (MVP) |
| Tanggal | 2026-09-23 |
| Platform | Web app / PWA (installable, offline) |
| Stack | Vite + React + TypeScript, localStorage, tanpa backend |

---

## 1. Latar Belakang

Pertandingan badminton rekreasi dan klub sering dicatat manual (ingatan, kertas, flip-board). Akibatnya sering lupa skor, salah posisi servis (terutama ganda), dan tidak ada catatan hasil. Aplikasi papan skor umumnya penuh iklan, butuh akun, atau tidak mendukung sistem poin lama (service-over) yang masih dipakai di sebagian komunitas.

## 2. Tujuan

1. Catat skor secepat mungkin: satu tap = satu rally, bisa satu tangan, dari pinggir lapangan.
2. Aturan servis otomatis & benar: siapa servis, dari kotak mana, siapa penerima.
3. Mendukung **Single / Double** dan **Rally point / Service-over**.
4. Bekerja offline, tanpa akun, tanpa internet.

### Metrik Sukses
- Tap → skor ter-update < 50 ms.
- 0 kesalahan aturan pada unit test engine.
- Lolos kriteria installable PWA; berfungsi penuh offline.
- Match aktif tidak hilang saat browser ditutup / reload.

## 3. Pengguna

| Persona | Kebutuhan |
|---|---|
| Pemain rekreasi | Catat skor main bareng teman, tanpa ribet |
| Wasit / pengurus klub | Posisi servis benar di ganda, interval & pindah sisi tepat |
| Pelatih | Riwayat hasil latih tanding |

## 4. Mode Permainan

Dua dimensi mode, bebas dikombinasikan (4 kombinasi):

| Dimensi | Opsi |
|---|---|
| Format | **Single** (1 vs 1), **Double** (2 vs 2) |
| Sistem poin | **Rally point** (BWF modern), **Service-over** (sistem lama) |

## 5. Aturan Scoring

### 5.1 Rally point
- Setiap rally menghasilkan 1 poin untuk pemenang rally.
- Pemenang rally melakukan servis berikutnya.
- Default: target 21, deuce aktif (menang selisih 2), batas maks 30 (poin ke-30 langsung menang).

### 5.2 Service-over (sistem lama)
- Poin hanya didapat tim yang sedang servis.
- Jika penerima memenangkan rally → skor tetap, hak servis berpindah ("service over").
- Default: target 30, setting aktif: jika 29-29, game berlanjut sampai 32 (poin ke-32 menang). Target 15 (setting 14-14 → 17) tetap bisa dipilih.

### 5.3 Kotak servis
- Single: skor server genap → servis dari kotak kanan; ganjil → kiri.
- Penerima selalu berada di kotak diagonal (sisi sama: kanan/kanan, kiri/kiri).

### 5.4 Double — rally point
- Tim servis menang rally → server yang sama pindah kotak (tukar posisi dengan partner).
- Tim penerima menang rally → dapat poin + hak servis, posisi tidak berubah; server = pemain di kotak sesuai paritas skor tim (genap kanan, ganjil kiri).

### 5.5 Double — service-over
- Awal game: tim yang servis hanya punya 1 kesempatan server ("one hand down").
- Setelahnya: tiap tim punya server 1 dan server 2.
  - Server 1 kalah rally → partner menjadi server 2.
  - Server 2 kalah rally → service over; pemain di kotak kanan tim lawan menjadi server 1.
- Tim servis menang rally → +1 poin, server pindah kotak.

### 5.6 Game & Match
- Best of 1 atau best of 3.
- Pemenang game servis duluan di game berikutnya.
- Pindah sisi lapangan setiap selesai game.
- Interval saat skor tertinggi mencapai setengah target (dibulatkan ke atas; 11 untuk 21, 15 untuk 30, 8 untuk 15). Di game penentu (game 3), pemain juga pindah sisi saat interval.

## 6. Fitur (MVP)

| ID | Fitur | Kriteria Penerimaan |
|---|---|---|
| F1 | **Setup match** | Pilih format, sistem poin, best of 1/3, nama pemain (1 atau 2 per tim), tim yang servis pertama. Default nama terisi ("Tim A"/"Tim B"). |
| F2 | **Setting poin custom** | Target (11/15/21/30/custom), deuce/setting on-off, batas maks. Preset otomatis berganti saat ganti sistem poin. Validasi: maks ≥ target. |
| F3 | **Scoreboard layar penuh** | Landscape: layar dibagi kiri–kanan, tap separuh layar = tim itu menang rally. Portrait: atas–bawah. Angka skor sangat besar, terbaca dari 3 m. |
| F4 | **Indikator servis** | Tanda shuttle di tim yang servis, nama server & penerima, kotak kanan/kiri, diagram mini posisi pemain (double), label "Server 1/2" (service-over double). |
| F5 | **Undo & log rally** | Undo tanpa batas dalam match (termasuk membatalkan akhir game). Log urutan rally per game dengan skor berjalan. |
| F6 | **Best of 3 & ganti sisi** | Skor game tercatat, pindah sisi otomatis antar game dan saat interval game penentu, modal interval & akhir game. Tombol tukar sisi manual. |
| F7 | **Riwayat match** | Match selesai disimpan ke localStorage; daftar match (tanggal, pemain, skor per game, pemenang); detail; hapus. |
| F8 | **UX pinggir lapangan** | Layar tidak mati (Wake Lock), mode fullscreen, getar singkat tiap poin, tema terang kontras tinggi (merah vs biru), area sentuh besar, safe-area notch. |
| F9 | **Resume** | Match aktif tersimpan otomatis; buka ulang app → tawaran lanjutkan. |
| F10 | **PWA / offline** | Installable, ikon, orientasi landscape pada manifest, aset di-cache. |

## 7. Alur Pengguna

```
Home ──► Setup ──► Scoreboard ──► (Interval) ──► (Akhir game) ──► ... ──► Akhir match ──► Simpan ──► Riwayat
  │                    ▲
  ├─ Lanjutkan match ──┘
  └─ Riwayat ──► Detail match
```

## 8. Desain Layar

### Scoreboard (landscape)
```
┌──────────────────────┬─────────┬─────┬─────────┬──────────────────────┐
│ [A] Budi / Andi  ● ○ │  KIRI   │ G1  │ KANAN   │ ○ ○  Cici / Dodi [B] │
│                      │  Andi   │ 1-0 │ Cici    │                      │
│       GAME POINT     ├─────────┤  ↶  │ TERIMA  │                      │
│          20          │ KANAN   │  ⇄  ├─────────┤          9           │
│                      │ Budi    │  ≡  │  KIRI   │                      │
│ Budi servis dr kanan │ SERVIS  │  ☰  │  Dodi   │  Menerima: Cici      │
└──────────────────────┴─────────┴─────┴─────────┴──────────────────────┘
  panel merah (servis: warna penuh)    net     panel biru (terima: pucat)
```
- Setiap separuh layar adalah tombol besar.
- Kontrol ada di strip net tengah, terpisah dari area tap tim untuk mencegah salah sentuh.
- Warna tim konsisten: A = merah, B = biru, tema terang.
- Kedua kartu skor selalu berwarna penuh (A merah, B biru); tim yang servis ditandai bingkai kuning + label "Servis". Kotak servis kanan/kiri dengan avatar pemain menempel ke sisi net.
- Strip tengah bergaya net berisi kontrol; badge Game point / Match point; umpan balik "+1" / "Pindah servis" per tap.
- Beranda: tombol mulai cepat (Single/Double × Rally/Service-over) memakai nama pemain terakhir.

## 9. Kebutuhan Non-Fungsional
- Mobile-first, 320 px – tablet 1366 px; landscape diutamakan, portrait tetap bisa dipakai.
- Tanpa dependensi UI eksternal; bundle JS < 100 KB gzip.
- Aksesibilitas: kontras AA, tombol ber-label, ukuran sentuh ≥ 44 px.
- Data hanya di perangkat (privasi).

## 10. Di Luar Cakupan (MVP)
Akun/login, sinkronisasi online, turnamen/bracket, statistik lanjutan, live share ke penonton, suara/voice announce.

## 11. Arsitektur Singkat
- `src/engine/` — logika murni TypeScript (immutable): `scoreRally(state, side)` → state baru. Semua aturan di sini, diuji unit test (Vitest).
- `src/store/` — reducer: state awal + daftar aksi; undo = replay tanpa aksi terakhir. Persist ke localStorage (beberapa KB per match).
- `src/screens/`, `src/components/` — UI React, hanya render state.

## 12. Rencana Lanjutan
- Statistik (rally terpanjang beruntun, poin per server).
- Share hasil sebagai gambar.
- Mode penonton (tampilan skor di layar kedua).
- Suara pengumuman skor.
