# ☁️ Proyek Cloud Computing: Cloud Media Hub & Serverless Storage Pipeline
> **Penggabungan Layanan AWS: VPC, EC2, EFS, S3, dan Lambda**  
> Dikerjakan Berbasis **AWS Management Console** pada Lingkungan **AWS Academy / Learner Lab**.

---

## 📋 Daftar Isi
1. [Arsitektur Sistem & Alur Integrasi](#-arsitektur-sistem--alur-integrasi)
2. [Aturan Khusus AWS Learner Lab](#-aturan-khusus-aws-learner-lab)
3. [Langkah 1: Setup Jaringan VPC & Security Groups](#langkah-1-setup-jaringan-vpc--security-groups)
4. [Langkah 2: Setup Amazon S3 Bucket](#langkah-2-setup-amazon-s3-bucket)
5. [Langkah 3: Setup Amazon EFS (Elastic File System)](#langkah-3-setup-amazon-efs-elastic-file-system)
6. [Langkah 4: Deploy Server EC2 & Auto-Mount EFS](#langkah-4-deploy-server-ec2--auto-mount-efs)
7. [Langkah 5: Setup AWS Lambda & S3 Event Trigger](#langkah-5-setup-aws-lambda--s3-event-trigger)
8. [Langkah 6: Pengujian End-to-End & Demonstrasi](#langkah-6-pengujian-end-to-end--demonstrasi)
9. [Troubleshooting & Solusi Masalah Umum](#-troubleshooting--solusi-masalah-umum)

---

## 🏛️ Arsitektur Sistem & Alur Integrasi

Aplikasi ini mendemonstrasikan kolaborasi nyata antara 5 layanan inti AWS:
* **Amazon VPC**: Mengisolasi arsitektur jaringan secara aman dengan subnet publik dan privat.
* **Amazon EC2**: Menyediakan komputasi web server dinamis (Apache & PHP) yang terhubung ke IAM `LabRole`.
* **Amazon EFS**: Menyediakan sistem berkas bersama (Shared File System) berkinerja tinggi lewat protokol NFS yang di-mount langsung ke sistem operasi Linux EC2.
* **Amazon S3**: Menyediakan penyimpanan objek (Object Storage) untuk menerima berkas media dari user atau backup.
* **AWS Lambda**: Menjalankan fungsi serverless (Python 3.12) secara otomatis setiap kali ada berkas baru di S3 untuk mengekstrak metadata dan menyimpan laporannya ke format JSON.

```
+-----------------------------------------------------------------------------------+
|  AWS Cloud (Region: us-east-1)                                                   |
|                                                                                   |
|  +--------------------------- VPC: 10.0.0.0/16 --------------------------------+ |
|  |                                                                             | |
|  |  [Public Subnet: 10.0.1.0/24]                [Private Subnet: 10.0.2.0/24]  | |
|  |  +-------------------------+                 +---------------------------+  | |
|  |  |  Amazon EC2 Instance    |  NFS Port 2049  |  Amazon EFS File System   |  | |
|  |  |  (Web Dashboard App)   | <=============> |  (Shared Web Storage)     |  | |
|  |  +-------------------------+                 +---------------------------+  | |
|  |               |                                                             | |
|  +---------------|-------------------------------------------------------------+ |
|                  | (Upload via AWS CLI / IAM LabRole)                            |
|                  v                                                               |
|  +-------------------------------------+      Event Notification                 |
|  |  Amazon S3 Bucket                   | ----------------------------+           |
|  |  - /uploads/    (Raw files)         |                             |           |
|  |  - /processed/  (Metadata JSON) <---+                             v           |
|  +-------------------------------------+                    +------------------+ |
|                                                             |  AWS Lambda      | |
|                                                             |  (Python 3.12)   | |
|                                                             +------------------+ |
+-----------------------------------------------------------------------------------+
```

---

## ⚠️ Aturan Khusus AWS Learner Lab
Harap perhatikan ketentuan lingkungan Learner Lab agar tidak menemui error izin (*Permission Denied*):
1. **Dilarang Membuat IAM Role Baru**: Learner Lab melarang pemanggilan API `iam:CreateRole`. **Gunakan selalu role bawaan: `LabRole`** (untuk Lambda) dan **`LabInstanceProfile`** (untuk EC2).
2. **Gunakan Region Default**: Selalu pastikan sudut kanan atas console AWS berada di region **US East (N. Virginia) `us-east-1`**.
3. **Masa Aktif Sesi Lab**: Sesi lab aktif selama maksimal 4 jam. Jika waktu habis, klik **Start Lab** kembali. Resource Anda tidak akan hilang selama lab tidak di-*Reset*.

---

## Langkah 1: Setup Jaringan VPC & Security Groups

### A. Membuat VPC dengan Wizard "VPC and more"
1. Masuk ke **AWS Management Console** -> Cari dan buka layanan **VPC**.
2. Pastikan region berada di **us-east-1**.
3. Klik tombol oranye **Create VPC**.
4. Pilih opsi **VPC and more**:
   * **Name tag auto-generation**: `lab-project-vpc`
   * **IPv4 CIDR block**: `10.0.0.0/16`
   * **Number of Availability Zones (AZs)**: `1`
   * **Number of public subnets**: `1`
   * **Number of private subnets**: `1`
   * **NAT gateways ($)**: `None`
   * **VPC Endpoints**: `None`
5. Klik **Create VPC**. Tunggu beberapa detik hingga seluruh komponen (VPC, Subnet, Route Table, Internet Gateway) selesai dibuat.

### B. Membuat Security Group untuk EC2 dan EFS
Masuk ke menu panel kiri: **Security > Security groups**.

#### 1. Security Group untuk EC2 (`EC2-Web-SG`)
1. Klik **Create security group**.
2. Isikan data:
   * **Security group name**: `EC2-Web-SG`
   * **Description**: `Akses HTTP dan SSH untuk EC2 Web Server`
   * **VPC**: Pilih `lab-project-vpc` (Hapus pilihan default jika ada).
3. Pada bagian **Inbound rules**, tambahkan 2 aturan:
   * **Rule 1**:
     * *Type*: `HTTP` (Port 80)
     * *Source*: `Anywhere-IPv4` (`0.0.0.0/0`)
   * **Rule 2**:
     * *Type*: `SSH` (Port 22)
     * *Source*: `Anywhere-IPv4` (`0.0.0.0/0`)
4. Klik **Create security group**.

#### 2. Security Group untuk EFS (`EFS-Storage-SG`)
1. Klik **Create security group** lagi.
2. Isikan data:
   * **Security group name**: `EFS-Storage-SG`
   * **Description**: `Akses NFS hanya dari EC2-Web-SG`
   * **VPC**: Pilih `lab-project-vpc`.
3. Pada bagian **Inbound rules**, tambahkan 1 aturan:
   * *Type*: `NFS` (Port 2049)
   * *Source*: Pilih **Custom**, lalu cari dan pilih Security Group **`EC2-Web-SG`**.
   *(Langkah ini sangat penting agar EFS hanya dapat diakses secara aman oleh EC2)*.
4. Klik **Create security group**.

---

## Langkah 2: Setup Amazon S3 Bucket

1. Buka layanan **Amazon S3**.
2. Klik tombol **Create bucket**:
   * **Bucket name**: `media-hub-lab-[nama-anda]-[nomor-unik]` *(Contoh: `media-hub-lab-budi-9821`)*.
   * **AWS Region**: `us-east-1`.
   * Biarkan pengaturan lain tetap default (*Block all public access* tetap tercentang).
3. Klik **Create bucket** di bagian paling bawah.
4. Klik nama bucket yang baru saja dibuat untuk membukanya.
5. Klik tombol **Create folder**:
   * Masukkan nama folder: `uploads` lalu klik **Create folder**.
6. Ulangi, klik **Create folder**:
   * Masukkan nama folder: `processed` lalu klik **Create folder**.

---

## Langkah 3: Setup Amazon EFS (Elastic File System)

1. Buka layanan **EFS**.
2. Klik tombol **Create file system**:
   * **Name**: `shared-media-efs`
   * **VPC**: Pilih `lab-project-vpc`.
   * **JANGAN** langsung klik Create, melainkan klik tombol **Customize**.
3. Di tab *File system settings*, biarkan default lalu klik **Next**.
4. Di tab *Network*:
   * Pastikan VPC adalah `lab-project-vpc`.
   * Pada tabel Subnet/Mount Targets:
     * Ubah Security Group default yang terpasang menjadi **`EFS-Storage-SG`**.
5. Klik **Next** -> **Next** -> lalu klik **Create**.
6. Tunggu status File System berubah menjadi **Available**.
7. Salin dan catat **File System ID** yang muncul (misalnya: `fs-0123456789abcdef0`).

---

## Langkah 4: Deploy Server EC2 & Auto-Mount EFS

1. Buka layanan **EC2** -> Klik **Instances** -> Klik **Launch instances**.
2. **Name and tags**:
   * **Name**: `Web-Server-App`
3. **Application and OS Images (Amazon Machine Image)**:
   * Pilih **Amazon Linux 2023 AMI** (Default Free tier).
4. **Instance type**:
   * Pilih `t2.micro` atau `t3.micro`.
5. **Key pair (login)**:
   * Pilih `vockey` (Key pair bawaan Learner Lab) atau *Proceed without a key pair*.
6. **Network settings** (Klik **Edit** di kanan atas kotak):
   * **VPC**: Pilih `lab-project-vpc`.
   * **Subnet**: Pilih **Public subnet** (`lab-project-vpc-subnet-public1...`).
   * **Auto-assign public IP**: Pilih **Enable** *(Wajib agar instance memiliki IP publik)*.
   * **Firewall (security groups)**: Pilih *Select existing security group*, lalu centang **`EC2-Web-SG`**.
7. **Advanced details** (Klik untuk membuka dropdown):
   * **IAM instance profile**: Pilih **`LabInstanceProfile`** (atau `LabRole`). *(Wajib dipilih agar EC2 diizinkan berinteraksi dengan S3 tanpa memasukkan access key manual)*.
   * Scroll ke baris paling bawah pada kolom **User data**.
   * Buka file [`web-app/setup-ec2.sh`](file:///e:/2026/Materi/cloud%20computing/projet2_storage/web-app/setup-ec2.sh), salin seluruh isinya, dan tempelkan ke kolom **User data**.
   * ⚠️ **PENTING**: Pada baris ke-8 di User data, ganti `EFS_ID="fs-xxxxxxxxxxxxxxxxx"` dengan File System ID EFS Anda dari Langkah 3!
8. Klik tombol **Launch instance**.
9. Tunggu hingga status instance menjadi **Running** dan Status check **2/2 checks passed** (sekitar 2–3 menit agar script User data selesai berjalan).
10. Salin **Public IPv4 address** EC2 Anda, lalu buka di browser: `http://<IP-PUBLIK-EC2>`. Anda akan melihat antarmuka **Cloud Media Hub Dashboard**.

---

## Langkah 5: Setup AWS Lambda & S3 Event Trigger

### A. Membuat Fungsi Lambda
1. Buka layanan **AWS Lambda**.
2. Klik **Create function**:
   * Pilih opsi **Author from scratch**.
   * **Function name**: `ProcessMediaUpload`
   * **Runtime**: `Python 3.12`
   * Buka bagian **Change default execution role**:
     * Pilih **Use an existing role**.
     * Pada dropdown *Existing role*, pilih **`LabRole`**.
3. Klik **Create function**.

### B. Memasukkan Kode Pemroses
1. Pada tab **Code**, klik ganda pada file `lambda_function.py`.
2. Hapus isi defaultnya, lalu salin dan tempelkan seluruh kode dari file [`lambda/lambda_function.py`](file:///e:/2026/Materi/cloud%20computing/projet2_storage/lambda/lambda_function.py).
3. Klik tombol **Deploy** (di atas editor kode).

### C. Menghubungkan Trigger S3 ke Lambda
1. Di halaman fungsi Lambda yang sama, lihat diagram di atas dan klik **+ Add trigger**.
2. Pada dropdown *Select a source*, pilih **S3**:
   * **Bucket**: Pilih bucket S3 yang telah dibuat di Langkah 2 (`media-hub-lab-...`).
   * **Event types**: `All object create events` (atau `s3:ObjectCreated:*`).
   * **Prefix**: `uploads/` *(Sangat penting: hanya memicu file di folder uploads)*.
   * Centang kotak persetujuan: *"I acknowledge that using the same S3 bucket for both input and output is not recommended..."*
3. Klik **Add**.

---

## Langkah 6: Pengujian End-to-End & Demonstrasi

Lakukan 3 pengujian berikut untuk membuktikan integrasi kelima layanan:

### 1. Uji Coba Penyimpanan Persisten EFS (EC2 + VPC + EFS)
1. Buka dashboard web di browser Anda (`http://<IP-PUBLIK-EC2>`).
2. Periksa kotak statistik di bagian atas:
   * **VPC & Subnet**: Menampilkan IP privat EC2 (dimulai dengan `10.0.1.x`).
   * **Status Mount Amazon EFS**: Harus berstatus **Ter-Mount (NFS Active)**.
3. Pada panel **1. Amazon EFS Storage Manager**:
   * Pilih sebuah berkas (misal gambar atau dokumen teks).
   * Klik **Simpan ke EFS**.
   * Berkas akan muncul di tabel daftar file EFS dengan rincian ukuran dan tanggal.
   * *Verifikasi konsep*: Berkas ini tersimpan di storage terdistribusi EFS pada port 2049, bukan sekadar di harddisk lokal EC2.

### 2. Uji Coba Serverless Event Pipeline (EC2 + S3 + Lambda)
1. Pada panel **2. Amazon S3 & Lambda Trigger** di dashboard:
   * Ketik nama S3 Bucket Anda di kolom input, lalu klik **Set Bucket**.
   * Pilih berkas gambar/dokumen lain pada form upload S3.
   * Klik tombol **Kirim ke S3 (Trigger Lambda)**.
2. Web akan mengirim file langsung ke `s3://[bucket-anda]/uploads/[nama-file]`.
3. Buka tab baru di browser Anda, lalu masuk ke **Console S3** -> buka folder **`processed/`**.
4. Dalam hitungan 1-3 detik, Anda akan melihat file baru bernama:  
   `[nama-file]_metadata.json`.
5. Klik file tersebut -> klik **Download** atau **Open** untuk melihat hasilnya. Anda akan melihat laporan ekstraksi metadata (ukuran file, tipe konten, timestamp, dsb.) yang dibuat secara serverless oleh **AWS Lambda**.

### 3. Uji Coba Monitoring di CloudWatch
1. Masuk ke console **AWS Lambda** -> buka fungsi `ProcessMediaUpload`.
2. Klik tab **Monitor** -> klik tombol **View CloudWatch logs**.
3. Buka Log Stream terbaru untuk melihat log eksekusi saat Lambda memproses event dari S3 secara realtime.

---

## 🛠️ Troubleshooting & Solusi Masalah Umum

| Gejala Masalah | Penyebab Utama | Solusi |
| :--- | :--- | :--- |
| **Website EC2 tidak bisa dibuka di browser** | Port 80 belum terbuka di Security Group atau Public IP belum ada. | Pastikan `EC2-Web-SG` memiliki Inbound Rule: HTTP Port 80 dari `0.0.0.0/0`, dan EC2 memiliki *Public IPv4*. |
| **Status EFS di web: "Tidak Terdeteksi"** | Script user data belum selesai atau Security Group EFS salah. | 1. Tunggu 2-3 menit.<br>2. Pastikan `EFS-Storage-SG` mengizinkan Inbound NFS port 2049 dari source `EC2-Web-SG`.<br>3. Pastikan ID EFS di script `setup-ec2.sh` sesuai dengan EFS ID Anda. |
| **Upload ke S3 dari web gagal** | EC2 belum dipasangi IAM Role yang sesuai. | Masuk ke console EC2 -> Pilih instance -> Klik menu **Actions > Security > Modify IAM role** -> Pilih **`LabInstanceProfile`** atau **`LabRole`** -> Klik **Update**. |
| **File JSON tidak muncul di folder `processed/`** | Trigger S3 belum terpasang atau Prefix salah. | Masuk ke console Lambda -> Cek bagian Triggers -> Pastikan trigger S3 berstatus *Enabled* dengan Prefix `uploads/`. Cek juga tab CloudWatch Logs untuk melihat detail error Python. |

---

## 🧹 Langkah Pembersihan Resource (Clean-up)
Setelah selesai presentasi atau pengujian, bersihkan resource untuk menghemat saldo lab:
1. **EC2**: Terminate instance `Web-Server-App`.
2. **EFS**: Delete file system `shared-media-efs`.
3. **Lambda**: Delete function `ProcessMediaUpload`.
4. **S3**: Empty bucket (kosongkan semua objek), lalu Delete bucket.
5. **VPC**: Delete VPC `lab-project-vpc` (akan otomatis menghapus subnet dan route table terkait).
# projet2_storage
