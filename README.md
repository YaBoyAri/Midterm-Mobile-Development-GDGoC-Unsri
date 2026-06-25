# Pov-Track (Poverty Tracker)

Aplikasi pencatat kemiskinan anda (keuangan pribadi) yang membantu pengguna mengelola pemasukan, pengeluaran, budget bulanan, tagihan, dan melihat laporan keuangan (kemiskinan) dalam bentuk grafik interaktif.

Dibangun dengan **Flutter** (frontend) dan **Supabase** (backend: Authentication + PostgreSQL Database).

---

## 📲 Download APK

Ingin langsung mencoba aplikasinya? Download APK terbaru dari halaman **Releases**:

👉 [**Download Poverty Tracker v1.0.0 (APK)**](https://github.com/YaBoyAri/Midterm-Mobile-Development-GDGoC-Unsri/releases/tag/v1.0.0)

> **Catatan:** Aktifkan **"Install from Unknown Sources"** di pengaturan HP Android kamu sebelum menginstall APK.

---

## Daftar Isi

- [Download APK](#-download-apk)
- [Apa Itu Pov-Track](#apa-itu-pov-track)
- [Fitur](#fitur)
- [Tech Stack & Dependensi](#tech-stack--dependensi)
- [Struktur Proyek](#struktur-proyek)
- [Informasi Backend](#informasi-backend)
- [Endpoint & Tabel Supabase](#endpoint--tabel-supabase)
- [Cara Menjalankan Aplikasi](#cara-menjalankan-aplikasi)
- [Skema Data (Tabel Supabase)](#skema-data-tabel-supabase)
- [Keamanan](#keamanan)

---

## Apa Itu Pov-Track

Pov-Track adalah aplikasi pencatat keuangan harian dengan alur yang sederhana:

1. **Daftar/masuk** menggunakan email & password
2. **Catat transaksi** — pilih tipe (pemasukan/pengeluaran), kategori, nominal, tanggal, dan catatan opsional
3. **Atur budget** — tetapkan batas pengeluaran per kategori setiap bulan, lihat progress pengeluaran secara real-time
4. **Kelola tagihan** — catat tagihan rutin (listrik, internet, Netflix, dll), tandai yang sudah dibayar, dan pantau jatuh tempo
5. **Lihat laporan** — visualisasi pemasukan vs pengeluaran dalam bentuk bar chart, pie chart pengeluaran per kategori, dan grafik tren mingguan

Aplikasi ini sepenuhnya menggunakan Supabase sebagai backend (Authentication + PostgreSQL), sehingga tidak ada server custom yang perlu di-deploy.

---

## Fitur

- **Autentikasi pengguna** — Registrasi dan login menggunakan email & password lewat Supabase Authentication. Sesi login tersimpan otomatis (auto-login saat membuka kembali aplikasi).
- **Dashboard utama** — Menampilkan saldo bulanan, ringkasan pemasukan & pengeluaran, dan daftar transaksi terakhir. Dilengkapi filter bulan dan pull-to-refresh.
- **Pencatatan transaksi (CRUD)** — Tambah, edit, dan hapus transaksi. Setiap transaksi memiliki tipe (income/expense), kategori dengan ikon & emoji, nominal, tanggal, dan catatan opsional. Hapus bisa dilakukan dengan swipe-to-delete atau lewat halaman edit.
- **Budget bulanan** — Membuat limit pengeluaran per kategori per bulan. Progress bar menunjukkan seberapa banyak yang sudah terpakai. Indikator peringatan muncul jika pengeluaran melebihi budget.
- **Manajemen tagihan** — Menambahkan tagihan dengan nama, nominal, dan tanggal jatuh tempo. Toggle status bayar/belum bayar. Peringatan visual untuk tagihan yang sudah lewat jatuh tempo.
- **Laporan keuangan interaktif** — Grafik bar chart perbandingan pemasukan vs pengeluaran, pie chart pengeluaran per kategori, grafik tren mingguan (line chart), dan detail transaksi per filter. Bisa difilter berdasarkan bulan.
- **Pengaturan akun** — Ubah username dan password langsung dari aplikasi. Logout dengan konfirmasi dan pembersihan sesi.
- **UI dark mode premium** — Tema gelap dengan glassmorphism, gradient, micro-animation (flutter_animate), floating bottom navigation bar, shimmer loading, dan tipografi Poppins.

---

## Tech Stack & Dependensi

| Layer | Teknologi |
|---|---|
| Framework UI | Flutter (Dart) |
| State Management | Riverpod 2.x (`flutter_riverpod`) |
| Navigasi | GoRouter 13.x (`go_router`) |
| Backend | Supabase (Authentication + PostgreSQL) |
| Chart / Grafik | fl_chart |
| Animasi | flutter_animate |
| Font | Google Fonts (Poppins) |
| Ikon | Iconsax |
| Format Tanggal & Mata Uang | intl (locale `id_ID`) |

Dependensi utama (lihat `pubspec.yaml` untuk versi pasti):

```yaml
supabase_flutter: ^2.3.4
flutter_riverpod: ^2.5.1
go_router: ^13.2.0
fl_chart: ^0.67.0
flutter_local_notifications: ^17.1.2
flutter_secure_storage: ^9.0.0
intl: ^0.19.0
iconsax: ^0.0.8
google_fonts: ^8.1.0
flutter_animate: ^4.5.2
```

---

## Struktur Proyek

Proyek mengikuti pendekatan **layered architecture** yang memisahkan data (model, service, provider) dan presentation (UI/screen):

```
lib/
├── main.dart                              # Entry point, inisialisasi Supabase
│
├── core/                                  # Kode yang dipakai lintas fitur
│   ├── constants/
│   │   └── supabase_constants.dart        # URL & Anon Key Supabase
│   ├── router/
│   │   └── app_router.dart                # Konfigurasi GoRouter + auth guard + bottom nav
│   └── theme/
│       └── app_theme.dart                 # Warna, gradient, glassmorphism, ThemeData
│
├── data/                                  # Layer data (model, service, provider)
│   ├── models/
│   │   ├── transaction_model.dart         # Model Transaksi (income/expense)
│   │   ├── budget_model.dart              # Model Budget per kategori per bulan
│   │   └── bill_model.dart                # Model Tagihan
│   ├── services/
│   │   ├── auth_service.dart              # Service autentikasi (signUp, signIn, signOut, dll)
│   │   ├── transaction_service.dart       # CRUD transaksi + ringkasan (getSummary)
│   │   ├── budget_service.dart            # CRUD budget + spending per kategori
│   │   └── bill_service.dart              # CRUD tagihan + toggle status bayar
│   └── repositories/
│       ├── auth_provider.dart             # Riverpod providers untuk auth
│       ├── transaction_provider.dart      # Riverpod providers untuk transaksi & summary
│       ├── budget_provider.dart           # Riverpod providers untuk budget & spending
│       └── bill_provider.dart             # Riverpod providers untuk tagihan
│
└── presentation/                          # Layer UI
    ├── auth/
    │   ├── login_screen.dart              # Halaman login
    │   └── register_screen.dart           # Halaman registrasi
    ├── home/
    │   └── home_screen.dart               # Dashboard utama (saldo, transaksi terakhir)
    ├── transaction/
    │   ├── add_transaction_screen.dart    # Form tambah transaksi
    │   └── edit_transaction_screen.dart   # Form edit transaksi
    ├── budget/
    │   └── budget_screen.dart             # Daftar budget & progress pengeluaran
    ├── report/
    │   └── report_screen.dart             # Laporan grafik & statistik
    ├── bill/
    │   └── bill_screen.dart               # Daftar tagihan
    └── settings/
        └── settings_screen.dart           # Pengaturan akun (username, password, logout)
```

Pemisahan layer `data` dan `presentation` membuat logic bisnis (service/provider) tidak bercampur dengan kode UI.

---

## Informasi Backend

Backend aplikasi ini sepenuhnya menggunakan **Supabase** (Backend-as-a-Service), bukan server custom:

- **Supabase Authentication** — menangani pendaftaran, login, manajemen sesi, dan penyimpanan metadata pengguna (display name) lewat email/password.
- **Supabase PostgreSQL Database** — database relasional yang menyimpan data transaksi, budget, dan tagihan. Aplikasi berkomunikasi langsung melalui Supabase Flutter SDK (`supabase_flutter`).

Tidak ada REST API custom, karena seluruh komunikasi data terjadi langsung antara Flutter SDK dan Supabase melalui SDK resmi.

---

## Endpoint & Tabel Supabase

Aplikasi ini mengakses Supabase melalui SDK (bukan REST endpoint manual), namun operasi yang dilakukan setara dengan endpoint REST berikut:

### Authentication

| Operasi | Method | Deskripsi |
|---|---|---|
| `signUp()` | POST `/auth/v1/signup` | Registrasi pengguna baru dengan email, password, dan display_name |
| `signInWithPassword()` | POST `/auth/v1/token?grant_type=password` | Login dengan email & password |
| `signOut()` | POST `/auth/v1/logout` | Logout dan hapus sesi |
| `updateUser()` | PUT `/auth/v1/user` | Update display_name atau password |
| `onAuthStateChange` | WebSocket | Stream status autentikasi real-time |

### Tabel `transactions`

| Operasi | Method | Endpoint Ekuivalen | Deskripsi |
|---|---|---|---|
| **Get all** | GET | `/rest/v1/transactions?user_id=eq.{uid}&order=date.desc` | Ambil semua transaksi milik user, diurutkan tanggal terbaru |
| **Add** | POST | `/rest/v1/transactions` | Tambah transaksi baru |
| **Update** | PATCH | `/rest/v1/transactions?id=eq.{id}` | Update transaksi berdasarkan ID |
| **Delete** | DELETE | `/rest/v1/transactions?id=eq.{id}` | Hapus transaksi berdasarkan ID |
| **Summary** | GET | `/rest/v1/transactions?user_id=eq.{uid}` | Ambil semua lalu hitung total income, expense, balance di client |

### Tabel `budgets`

| Operasi | Method | Endpoint Ekuivalen | Deskripsi |
|---|---|---|---|
| **Get by month** | GET | `/rest/v1/budgets?user_id=eq.{uid}&month=eq.{YYYY-MM}` | Ambil budget user untuk bulan tertentu |
| **Add** | POST | `/rest/v1/budgets` | Tambah budget baru per kategori per bulan |
| **Delete** | DELETE | `/rest/v1/budgets?id=eq.{id}` | Hapus budget berdasarkan ID |
| **Spending by category** | GET | `/rest/v1/transactions?user_id=eq.{uid}&type=eq.expense&date=gte.{start}&date=lte.{end}` | Ambil pengeluaran per kategori dari tabel `transactions` untuk bulan tertentu |

### Tabel `bills`

| Operasi | Method | Endpoint Ekuivalen | Deskripsi |
|---|---|---|---|
| **Get all** | GET | `/rest/v1/bills?user_id=eq.{uid}&order=due_date.asc` | Ambil semua tagihan user, diurutkan jatuh tempo terdekat |
| **Add** | POST | `/rest/v1/bills` | Tambah tagihan baru |
| **Toggle paid** | PATCH | `/rest/v1/bills?id=eq.{id}` | Update status `is_paid` (true/false) |
| **Delete** | DELETE | `/rest/v1/bills?id=eq.{id}` | Hapus tagihan berdasarkan ID |

---

## Cara Menjalankan Aplikasi

### Prasyarat

- Flutter SDK 3.x — [panduan instalasi](https://flutter.dev/docs/get-started/install)
- Akun Supabase (gratis) — [supabase.com](https://supabase.com)
- Untuk Android: Android Studio / Android SDK
- Untuk iOS: Mac + Xcode 15+

### 1. Clone repository

```bash
git clone <url-repo-hasil-fork-kamu>
cd poverty_tracker
```

### 2. Pasang dependensi

```bash
flutter pub get
```

### 3. Setup project Supabase

1. Buka [app.supabase.com](https://app.supabase.com) → buat project baru
2. Aktifkan **Authentication** → sign-in method **Email/Password**
3. Buat tabel-tabel berikut di **SQL Editor** (lihat bagian [Skema Data](#skema-data-tabel-supabase))
4. Terapkan **Row Level Security (RLS)** policies (lihat bagian [Keamanan](#keamanan))

### 4. Konfigurasi kredensial Supabase

Buka file `lib/core/constants/supabase_constants.dart` dan ganti dengan URL & Anon Key dari project Supabase milikmu:

```dart
class SupabaseConstants {
  static const String supabaseUrl = 'https://<PROJECT_ID>.supabase.co';
  static const String supabaseAnonKey = '<YOUR_ANON_KEY>';
}
```

Kamu bisa menemukan kedua nilai ini di Supabase Dashboard → **Settings** → **API**.

### 5. Jalankan aplikasi

```bash
flutter run
```

Untuk memilih device tertentu:

```bash
# Android
flutter run -d android

# iOS (Mac only)
flutter run -d ios

# Chrome (Web)
flutter run -d chrome
```

---

## Skema Data (Tabel Supabase)

Berikut SQL untuk membuat tabel-tabel yang digunakan. Jalankan di **SQL Editor** di Supabase Dashboard:

### Tabel `transactions`

```sql
CREATE TABLE transactions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  amount NUMERIC NOT NULL CHECK (amount > 0),
  category TEXT NOT NULL,
  note TEXT,
  date DATE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Index untuk query per user, diurutkan tanggal
CREATE INDEX idx_transactions_user_date ON transactions(user_id, date DESC);
```

### Tabel `budgets`

```sql
CREATE TABLE budgets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  category TEXT NOT NULL,
  limit_amount NUMERIC NOT NULL CHECK (limit_amount > 0),
  month TEXT NOT NULL,  -- format: 'YYYY-MM'
  created_at TIMESTAMPTZ DEFAULT now(),

  -- Satu user hanya bisa punya satu budget per kategori per bulan
  UNIQUE(user_id, category, month)
);

CREATE INDEX idx_budgets_user_month ON budgets(user_id, month);
```

### Tabel `bills`

```sql
CREATE TABLE bills (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  amount NUMERIC NOT NULL CHECK (amount > 0),
  due_date DATE NOT NULL,
  is_paid BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_bills_user_due ON bills(user_id, due_date ASC);
```

---

## Keamanan

### 1. Row Level Security (RLS)

Setiap tabel di Supabase harus memiliki RLS yang aktif agar pengguna hanya bisa mengakses data miliknya sendiri. Berikut policy yang perlu diterapkan:

```sql
-- ═══ transactions ═══
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own transactions"
  ON transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own transactions"
  ON transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own transactions"
  ON transactions FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own transactions"
  ON transactions FOR DELETE
  USING (auth.uid() = user_id);

-- ═══ budgets ═══
ALTER TABLE budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own budgets"
  ON budgets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own budgets"
  ON budgets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own budgets"
  ON budgets FOR DELETE
  USING (auth.uid() = user_id);

-- ═══ bills ═══
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own bills"
  ON bills FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own bills"
  ON bills FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own bills"
  ON bills FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own bills"
  ON bills FOR DELETE
  USING (auth.uid() = user_id);
```

### 2. Autentikasi wajib

Semua operasi data mengharuskan pengguna login terlebih dahulu. Router aplikasi memiliki guard yang otomatis mengarahkan pengguna ke halaman login jika belum terautentikasi.

### 3. Password tidak ditangani langsung

Seluruh proses hashing dan penyimpanan kredensial password ditangani oleh Supabase Authentication, bukan oleh kode aplikasi.

---

*Dibangun dengan Flutter · Supabase · Riverpod*