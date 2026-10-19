# LAPORAN AKHIR PRAKTIKUM CLOUD COMPUTING
## PROYEK INTEGRASI HYBRID STORAGE & SERVERLESS PIPELINE
### (AWS VPC, EC2, EFS, S3, DAN LAMBDA)

---

### 📝 IDENTITAS MAHASISWA / KELOMPOK
* **Nama Mahasiswa** : [Nama Lengkap Anda]
* **NIM**            : [Nomor Induk Mahasiswa]
* **Mata Kuliah**    : Cloud Computing
* **Program Studi**  : [Teknik Informatika / Sistem Informasi / Rekayasa Perangkat Lunak]
* **Dosen Pengampu** : [Nama Dosen]
* **Tanggal Lab**    : [Hari, Tanggal Praktikum]
* **Lingkungan Lab** : AWS Academy Learner Lab (Region: `us-east-1`)

---

## 1. TUJUAN PRAKTIKUM
1. Mampu merancang dan mengonfigurasi jaringan privat virtual (**Amazon VPC**) terisolasi lengkap dengan subnet publik dan privat, route table, serta security groups bertingkat.
2. Mampu menerapkan sistem penyimpanan berkas jaringan bersama (**Amazon EFS**) berbasis protokol NFS yang terhubung langsung ke mesin komputasi (**Amazon EC2**).
3. Mampu membangun antarmuka web interaktif yang memanfaatkan hak akses IAM berbasis peranan (**IAM LabRole/LabInstanceProfile**) tanpa menyimpan kredensial sensitif di dalam kode.
4. Mampu merancang arsitektur komputasi tanpa server berbasis kejadian (*Event-driven Serverless Architecture*) menggunakan **Amazon S3** dan **AWS Lambda**.
5. Mampu melakukan pengujian end-to-end, verifikasi integrasi lintas layanan, serta analisis monitoring melalui **Amazon CloudWatch Logs**.

---

## 2. ARSITEKTUR SISTEM & DIAGRAM ALUR

### A. Deskripsi Arsitektur
Arsitektur yang dibangun terdiri dari 5 pilar layanan utama AWS:
* **VPC (`10.0.0.0/16`)**: Jaringan induk yang mengisolasi seluruh infrastruktur.
  * **Public Subnet (`10.0.1.0/24`)**: Menempatkan instans EC2 web server yang terhubung ke Internet Gateway.
  * **Private Subnet (`10.0.2.0/24`)**: Menempatkan mount target penyimpanan Amazon EFS yang hanya dapat diakses melalui port NFS 2049 dari Security Group EC2.
* **EC2 Web Server**: Instans berbasis Amazon Linux 2023 yang menjalankan Apache dan PHP Dashboard. Instans ini menggunakan IAM `LabInstanceProfile`.
* **Amazon EFS**: Media penyimpanan terdistribusi untuk kebutuhan aplikasi web yang membutuhkan persistensi tinggi antar-instance.
* **Amazon S3**: Tempat penyimpanan objek untuk menampung file unggahan pengguna di folder `uploads/` dan menyimpan hasil olahan di folder `processed/`.
* **AWS Lambda**: Pemroses serverless yang terpicu secara otomatis oleh event `s3:ObjectCreated:*` untuk menganalisis metadata berkas dan menyimpannya ke format JSON.

### B. Diagram Alur
```
[User Browser]
      |
      | HTTP (Port 80)
      v
[EC2 Web Server (Public Subnet)] <==== NFS (Port 2049) ====> [Amazon EFS (Private Subnet)]
      |
      | Upload file via AWS CLI (LabRole)
      v
[Amazon S3 Bucket: /uploads/] 
      |
      | Event Trigger (s3:ObjectCreated:*)
      v
[AWS Lambda Function (Python 3.12)]
      |
      | Generate Metadata JSON
      v
[Amazon S3 Bucket: /processed/]
```

---

## 3. LANGKAH-LANGKAH IMPLEMENTASI & BUKTI SCREENSHOT

*(Petunjuk: Tempelkan tangkapan layar (screenshot) console AWS Anda pada setiap bagian placeholder di bawah)*

### Langkah 3.1: Konfigurasi Jaringan VPC & Security Groups
* **Detail Konfigurasi**:
  * Nama VPC: `lab-project-vpc` (CIDR: `10.0.0.0/16`)
  * Security Group EC2 (`EC2-Web-SG`): Inbound HTTP 80 & SSH 22.
  * Security Group EFS (`EFS-Storage-SG`): Inbound NFS 2049 dari `EC2-Web-SG`.

> 📷 **Bukti Screenshot 1: Resource Map VPC & Security Groups**  
> *(Ganti baris ini dengan gambar tampilan VPC dan Security Groups di AWS Console)*  
> `[TEMPELKAN GAMBAR DI SINI]`

---

### Langkah 3.2: Pembuatan Amazon S3 Bucket & Folder
* **Detail Konfigurasi**:
  * Nama Bucket: `[Nama-Bucket-Anda]`
  * Struktur Folder: `uploads/` dan `processed/`

> 📷 **Bukti Screenshot 2: Tampilan Bucket S3 dan Strukturnya**  
> `[TEMPELKAN GAMBAR DI SINI]`

---

### Langkah 3.3: Konfigurasi Amazon EFS (Elastic File System)
* **Detail Konfigurasi**:
  * File System ID: `[Contoh: fs-0123456789abcdef0]`
  * Mount Target Subnet: Terhubung dengan `lab-project-vpc` menggunakan `EFS-Storage-SG`.

> 📷 **Bukti Screenshot 3: Status File System EFS "Available" dan Mount Targets**  
> `[TEMPELKAN GAMBAR DI SINI]`

---

### Langkah 3.4: Peluncuran Instance EC2 & Mount EFS
* **Detail Konfigurasi**:
  * Instance ID: `[Contoh: i-0abc1234def567890]`
  * AMI: Amazon Linux 2023 | Instance Type: `t2.micro` / `t3.micro`
  * IAM Instance Profile: `LabInstanceProfile`
  * Public IP: `[IP Public EC2]`

> 📷 **Bukti Screenshot 4: Tampilan Instance EC2 "Running" & 2/2 Checks Passed**  
> `[TEMPELKAN GAMBAR DI SINI]`

---

### Langkah 3.5: Pembuatan AWS Lambda Function & S3 Trigger
* **Detail Konfigurasi**:
  * Nama Fungsi: `ProcessMediaUpload`
  * Runtime: Python 3.12
  * Execution Role: `LabRole`
  * S3 Trigger Prefix: `uploads/`

> 📷 **Bukti Screenshot 5: Diagram Fungsi Lambda beserta S3 Trigger Terhubung**  
> `[TEMPELKAN GAMBAR DI SINI]`

---

## 4. HASIL PENGUJIAN & VERIFIKASI AKHIR

### Pengujian 1: Tampilan Dashboard Web & Verifikasi Mount EFS
Aplikasi web diakses melalui browser pada alamat `http://[IP-PUBLIK-EC2]`. Terverifikasi bahwa status mount EFS aktif (NFS Active) dan file berhasil diunggah serta tersimpan pada storage persisten EFS.

> 📷 **Bukti Screenshot 6: Dashboard Web Cloud Media Hub dengan File di EFS**  
> `[TEMPELKAN GAMBAR DI SINI]`

---

### Pengujian 2: Alur Unggah S3 & Pemrosesan Otomatis oleh Lambda
File diunggah ke S3 melalui form web. Lambda merespons event unggahan secara realtime dan menghasilkan berkas metadata di folder `processed/`.

> 📷 **Bukti Screenshot 7: Berkas Metadata JSON di Folder `processed/` S3**  
> `[TEMPELKAN GAMBAR DI SINI]`

> 📄 **Contoh Konten Berkas Hasil Olahan Lambda (`_metadata.json`):**
```json
{
    "project": "Cloud Computing - Storage & Serverless Pipeline",
    "processed_at_utc": "2026-10-19 06:30:15 UTC",
    "source": {
        "bucket": "media-hub-lab-budi-9821",
        "folder": "uploads",
        "file_name": "sample-dokumen.pdf",
        "full_path": "uploads/sample-dokumen.pdf"
    },
    "file_attributes": {
        "size_bytes": 1048576,
        "size_kb": 1024.0,
        "size_mb": 1.0,
        "extension": "pdf",
        "content_type": "application/pdf",
        "etag": "0123456789abcdef0123456789abcdef",
        "s3_last_modified": "2026-10-19 06:30:12+00:00"
    },
    "processing_info": {
        "processed_by": "AWS Lambda (Python 3.12)",
        "execution_role": "LabRole",
        "status": "SUCCESS"
    }
}
```

---

### Pengujian 3: Verifikasi Log Eksekusi di Amazon CloudWatch
Pemeriksaan log eksekusi pada layanan CloudWatch membuktikan bahwa fungsi Lambda berhasil dieksekusi tanpa error.

> 📷 **Bukti Screenshot 8: CloudWatch Log Streams Eksekusi Lambda**  
> `[TEMPELKAN GAMBAR DI SINI]`

---

## 5. ANALISIS & PEMBAHASAN INTEGRASI LAYANAN

1. **Keamanan Jaringan (VPC & Security Groups)**:  
   Penyimpanan bersama EFS tidak dapat diakses langsung oleh internet publik. Komunikasi ke EFS dibatasi hanya melalui port NFS 2049 yang berasal dari referensi Security Group instance EC2 (`EC2-Web-SG`). Hal ini menerapkan prinsip *Least Privilege* pada tingkat jaringan.
2. **Efisiensi Penyimpanan Persisten (EFS vs EBS)**:  
   Berbeda dengan EBS yang terikat pada satu instance di satu AZ (*block storage*), EFS menyediakan sistem berkas terdistribusi (*file storage*) yang dapat diakses secara bersamaan (*multi-attach*) oleh puluhan hingga ratusan instance di berbagai subnet.
3. **Penerapan IAM Role Tanpa Kredensial Statis**:  
   Penggunaan IAM Instance Profile (`LabInstanceProfile`/`LabRole`) pada instance EC2 memungkinkan web server berinteraksi langsung dengan Amazon S3 tanpa perlu menyimpan *AWS Access Key* dan *Secret Key* di dalam script PHP, mencegah risiko kebocoran kunci akses.
4. **Keunggulan Arsitektur Event-Driven (S3 + Lambda)**:  
   Dengan memanfaatkan S3 Event Notification yang memicu AWS Lambda, sistem tidak memerlukan proses *background polling* atau daemon yang terus menerus berjalan di EC2. Komputasi hanya aktif dan mengonsumsi biaya saat ada berkas yang masuk (*true pay-as-you-go serverless*).

---

## 6. KESIMPULAN
Melalui proyek ini, sistem manajemen media berbasis cloud berhasil diimplementasikan dengan menggabungkan 5 layanan fundamental AWS:
1. **Amazon VPC** menjamin segmentasi jaringan yang aman.
2. **Amazon EC2** menjalankan antarmuka aplikasi web dinamis.
3. **Amazon EFS** menyajikan penyimpanan berkas persisten terdistribusi yang handal.
4. **Amazon S3** menjadi fondasi penyimpanan objek jangka panjang yang scalable.
5. **AWS Lambda** melengkapi alur kerja dengan komputasi nirserver (*serverless*) yang efisien dan responsif terhadap event.

Seluruh konfigurasi dapat diselesaikan menggunakan antarmuka grafis **AWS Management Console** dengan mematuhi seluruh batasan perizinan pada lingkungan **AWS Learner Lab**.
