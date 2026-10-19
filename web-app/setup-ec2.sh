#!/bin/bash
# ==============================================================================
# SCRIPT OTOMATISASI INSTALASI EC2 - WEB SERVER & EFS MOUNT
# Digunakan pada bagian "User data" saat Launch Instance di AWS Console
# ==============================================================================

# PERHATIAN: Ganti fs-xxxxxxxxxxxxxxxxx dengan File System ID EFS Anda!
EFS_ID="fs-xxxxxxxxxxxxxxxxx"

# 1. Update package repository & install Apache, PHP, AWS CLI, dan EFS Utils
dnf update -y
dnf install -y httpd php php-cli amazon-efs-utils nfs-utils

# 2. Buat direktori mount untuk EFS
mkdir -p /var/www/html/efs-data

# 3. Mount EFS ke direktori /var/www/html/efs-data
# Menggunakan tls dan helper amazon-efs-utils
if [ "$EFS_ID" != "fs-xxxxxxxxxxxxxxxxx" ]; then
    mount -t efs -o tls $EFS_ID:/ /var/www/html/efs-data
    # Tambahkan ke /etc/fstab agar persistent saat instance reboot
    echo "$EFS_ID:/ /var/www/html/efs-data efs _netdev,tls 0 0" >> /etc/fstab
fi

# 4. Ambil file web dashboard index.php dari script embedded
cat << 'EOF' > /var/www/html/index.php
<?php
// CLOUD MEDIA HUB - AWS VPC + EC2 + EFS + S3 + LAMBDA DASHBOARD
$efs_mount_point = "/var/www/html/efs-data";
$alert_message = "";
$alert_type = "";
$s3_config_file = "/var/www/html/s3_bucket.txt";
$s3_bucket = file_exists($s3_config_file) ? trim(file_get_contents($s3_config_file)) : "";

if (isset($_POST['set_s3_bucket'])) {
    $s3_bucket = trim($_POST['s3_bucket_name']);
    file_put_contents($s3_config_file, $s3_bucket);
    $alert_message = "Target S3 Bucket berhasil diperbarui ke: <b>" . htmlspecialchars($s3_bucket) . "</b>";
    $alert_type = "success";
}

if (isset($_POST['upload_efs']) && isset($_FILES['file_efs'])) {
    if (!is_dir($efs_mount_point)) { mkdir($efs_mount_point, 0775, true); }
    $file_name = basename($_FILES['file_efs']['name']);
    $target_path = $efs_mount_point . "/" . $file_name;
    if (move_uploaded_file($_FILES['file_efs']['tmp_name'], $target_path)) {
        $alert_message = "File <b>" . htmlspecialchars($file_name) . "</b> berhasil disimpan ke <b>Amazon EFS</b>!";
        $alert_type = "success";
    } else {
        $alert_message = "Gagal mengunggah file ke EFS.";
        $alert_type = "danger";
    }
}

if (isset($_GET['delete_efs'])) {
    $file_to_delete = basename($_GET['delete_efs']);
    $full_delete_path = $efs_mount_point . "/" . $file_to_delete;
    if (file_exists($full_delete_path)) {
        unlink($full_delete_path);
        $alert_message = "File <b>" . htmlspecialchars($file_to_delete) . "</b> berhasil dihapus dari EFS.";
        $alert_type = "info";
    }
}

if (isset($_POST['upload_s3']) && isset($_FILES['file_s3'])) {
    if (empty($s3_bucket)) {
        $alert_message = "Silakan tentukan nama target S3 Bucket terlebih dahulu!";
        $alert_type = "warning";
    } else {
        $file_name = basename($_FILES['file_s3']['name']);
        $temp_path = $_FILES['file_s3']['tmp_name'];
        $s3_destination = "s3://" . $s3_bucket . "/uploads/" . $file_name;
        $cmd = "aws s3 cp " . escapeshellarg($temp_path) . " " . escapeshellarg($s3_destination) . " 2>&1";
        $output = shell_exec($cmd);
        if (strpos($output, 'upload:') !== false) {
            $alert_message = "File <b>" . htmlspecialchars($file_name) . "</b> berhasil diunggah ke <b>$s3_destination</b>! Event ini otomatis memicu <b>AWS Lambda</b>.";
            $alert_type = "success";
        } else {
            $alert_message = "Gagal upload ke S3: <pre>" . htmlspecialchars($output) . "</pre>";
            $alert_type = "danger";
        }
    }
}

function get_ec2_metadata($path) {
    $token_opts = ['http' => ['method' => 'PUT', 'header' => 'X-aws-ec2-metadata-token-ttl-seconds: 60', 'timeout' => 1]];
    $token = @file_get_contents('http://169.254.169.254/latest/api/token', false, stream_context_create($token_opts));
    if (!$token) return "N/A";
    $opts = ['http' => ['method' => 'GET', 'header' => "X-aws-ec2-metadata-token: $token", 'timeout' => 1]];
    $val = @file_get_contents("http://169.254.169.254/latest/meta-data/$path", false, stream_context_create($opts));
    return $val ? trim($val) : "N/A";
}

$instance_id = get_ec2_metadata('instance-id');
$az = get_ec2_metadata('placement/availability-zone');
$local_ipv4 = get_ec2_metadata('local-ipv4');
$efs_mounted = !empty(shell_exec("mount | grep " . escapeshellarg($efs_mount_point)));

$efs_files = [];
if (is_dir($efs_mount_point)) {
    $scanned = array_diff(scandir($efs_mount_point), array('.', '..'));
    foreach ($scanned as $f) {
        $fp = $efs_mount_point . "/" . $f;
        $efs_files[] = [
            'name' => $f,
            'size' => round(filesize($fp) / 1024, 2),
            'modified' => date("Y-m-d H:i:s", filemtime($fp))
        ];
    }
}
?>
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cloud Media Hub - AWS Learner Lab Showcase</title>
    <style>
        :root { --primary: #4f46e5; --primary-hover: #4338ca; --aws-orange: #ff9900; --bg: #f8fafc; --card-bg: #ffffff; --text-main: #0f172a; --text-muted: #64748b; --border: #e2e8f0; --success: #10b981; --danger: #ef4444; --warning: #f59e0b; }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        body { background: var(--bg); color: var(--text-main); padding: 30px 20px; line-height: 1.5; }
        .container { max-width: 1100px; margin: 0 auto; }
        header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 25px; flex-wrap: wrap; gap: 15px; }
        .title-group h1 { font-size: 26px; font-weight: 800; color: #1e293b; }
        .aws-badge { background: #131921; color: var(--aws-orange); padding: 6px 14px; border-radius: 20px; font-weight: 700; font-size: 13px; }
        .alert { padding: 14px 18px; border-radius: 8px; margin-bottom: 25px; font-size: 14px; }
        .alert-success { background: #dcfce7; color: #166534; border-left: 5px solid var(--success); }
        .alert-danger { background: #fee2e2; color: #991b1b; border-left: 5px solid var(--danger); }
        .alert-warning { background: #fef3c7; color: #92400e; border-left: 5px solid var(--warning); }
        .alert-info { background: #e0f2fe; color: #075985; border-left: 5px solid #0284c7; }
        .grid-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 16px; margin-bottom: 25px; }
        .stat-card { background: var(--card-bg); padding: 18px; border-radius: 10px; border: 1px solid var(--border); }
        .stat-card .label { font-size: 12px; font-weight: 600; text-transform: uppercase; color: var(--text-muted); }
        .stat-card .val { font-size: 16px; font-weight: 700; margin-top: 6px; }
        .status-dot { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 6px; }
        .dot-green { background: var(--success); } .dot-red { background: var(--danger); }
        .grid-main { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; margin-bottom: 25px; }
        @media (max-width: 850px) { .grid-main { grid-template-columns: 1fr; } }
        .card { background: var(--card-bg); border-radius: 12px; border: 1px solid var(--border); overflow: hidden; }
        .card-header { padding: 16px 20px; background: #fafafa; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
        .card-header h2 { font-size: 16px; font-weight: 700; }
        .card-body { padding: 20px; }
        .upload-area { border: 2px dashed #cbd5e1; border-radius: 10px; padding: 20px 15px; text-align: center; background: #f8fafc; margin-bottom: 15px; }
        input[type="file"] { margin-bottom: 12px; font-size: 13px; }
        button, .btn { background: var(--primary); color: white; border: none; padding: 10px 18px; border-radius: 6px; font-weight: 600; font-size: 14px; cursor: pointer; }
        button:hover, .btn:hover { background: var(--primary-hover); }
        .btn-sm { padding: 5px 10px; font-size: 12px; }
        .btn-danger { background: var(--danger); }
        table { width: 100%; border-collapse: collapse; margin-top: 15px; font-size: 13px; }
        th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid var(--border); }
        th { background: #f1f5f9; color: #475569; font-weight: 600; }
        .architecture-banner { background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%); color: white; padding: 24px; border-radius: 12px; }
        .architecture-banner h3 { font-size: 18px; margin-bottom: 10px; color: var(--aws-orange); }
        .service-tags { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 14px; }
        .tag { background: rgba(255,255,255,0.1); padding: 5px 12px; border-radius: 15px; font-size: 12px; border: 1px solid rgba(255,255,255,0.15); }
    </style>
</head>
<body>
<div class="container">
    <header>
        <div class="title-group">
            <h1>🚀 Cloud Media Hub Dashboard</h1>
            <p>Implementasi Arsitektur Terdistribusi Berbasis AWS Learner Lab</p>
        </div>
        <div class="aws-badge">AWS Academy / Learner Lab</div>
    </header>

    <?php if (!empty($alert_message)): ?>
        <div class="alert alert-<?= $alert_type ?>"><?= $alert_message ?></div>
    <?php endif; ?>

    <div class="grid-stats">
        <div class="stat-card">
            <div class="label">VPC & Subnet (Private IP)</div>
            <div class="val"><?= htmlspecialchars($local_ipv4) ?></div>
        </div>
        <div class="stat-card">
            <div class="label">EC2 Instance ID & AZ</div>
            <div class="val"><?= htmlspecialchars($instance_id) ?> <span style="font-size:12px;color:var(--text-muted);">(<?= htmlspecialchars($az) ?>)</span></div>
        </div>
        <div class="stat-card">
            <div class="label">Status Mount Amazon EFS</div>
            <div class="val">
                <?php if ($efs_mounted): ?>
                    <span class="status-dot dot-green"></span> Ter-Mount (NFS Active)
                <?php else: ?>
                    <span class="status-dot dot-red"></span> Tidak Terdeteksi
                <?php endif; ?>
            </div>
        </div>
        <div class="stat-card">
            <div class="label">Target S3 Bucket</div>
            <div class="val"><?= !empty($s3_bucket) ? htmlspecialchars($s3_bucket) : '<span style="color:var(--warning);font-size:13px;">Belum Diisi</span>' ?></div>
        </div>
    </div>

    <div class="grid-main">
        <div class="card">
            <div class="card-header">
                <h2>📁 1. Amazon EFS Storage Manager</h2>
                <span style="font-size:12px;color:var(--text-muted);"><?= htmlspecialchars($efs_mount_point) ?></span>
            </div>
            <div class="card-body">
                <form method="POST" enctype="multipart/form-data">
                    <div class="upload-area">
                        <input type="file" name="file_efs" required><br>
                        <button type="submit" name="upload_efs">Simpan ke EFS</button>
                    </div>
                </form>
                <h3 style="font-size:14px;margin-top:15px;">Daftar File di EFS (<?= count($efs_files) ?>):</h3>
                <?php if (empty($efs_files)): ?>
                    <p style="font-size:13px;color:var(--text-muted);margin-top:10px;">Belum ada file di storage EFS.</p>
                <?php else: ?>
                    <table>
                        <thead>
                            <tr><th>Nama File</th><th>Ukuran</th><th>Waktu</th><th>Aksi</th></tr>
                        </thead>
                        <tbody>
                            <?php foreach ($efs_files as $f): ?>
                                <tr>
                                    <td><b><?= htmlspecialchars($f['name']) ?></b></td>
                                    <td><?= $f['size'] ?> KB</td>
                                    <td><?= $f['modified'] ?></td>
                                    <td><a href="?delete_efs=<?= urlencode($f['name']) ?>" class="btn btn-sm btn-danger">Hapus</a></td>
                                </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                <?php endif; ?>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2>⚡ 2. Amazon S3 & Lambda Trigger</h2>
                <span style="font-size:12px;color:var(--text-muted);">Event-driven Pipeline</span>
            </div>
            <div class="card-body">
                <form method="POST" style="margin-bottom:15px;background:#f1f5f9;padding:12px;border-radius:8px;">
                    <label style="font-size:12px;font-weight:600;display:block;margin-bottom:5px;">Nama S3 Bucket:</label>
                    <div style="display:flex;gap:8px;">
                        <input type="text" name="s3_bucket_name" value="<?= htmlspecialchars($s3_bucket) ?>" placeholder="media-hub-lab-xxx" required style="flex:1;padding:8px;border:1px solid var(--border);border-radius:6px;font-size:13px;">
                        <button type="submit" name="set_s3_bucket" class="btn-sm">Set Bucket</button>
                    </div>
                </form>
                <form method="POST" enctype="multipart/form-data">
                    <div class="upload-area">
                        <input type="file" name="file_s3" required><br>
                        <button type="submit" name="upload_s3" style="background:#ff9900;color:#111;">Kirim ke S3 (Trigger Lambda)</button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <div class="architecture-banner">
        <h3>🏛️ Diagram Alur & Keterhubungan Layanan</h3>
        <p style="font-size:13px;opacity:0.9;">
            Jaringan VPC mengisolasi instance EC2 dan Storage EFS dalam security group yang terproteksi; Instance profile LabRole memberikan akses aman dari EC2 ke S3 tanpa hardcode credentials; serta AWS Lambda bertindak sebagai pemroses serverless asinkronus berbasis event S3.
        </p>
        <div class="service-tags">
            <span class="tag">🌐 AWS VPC</span>
            <span class="tag">💻 Amazon EC2</span>
            <span class="tag">📂 Amazon EFS</span>
            <span class="tag">🪣 Amazon S3</span>
            <span class="tag">⚡ AWS Lambda</span>
        </div>
    </div>
</div>
</body>
</html>
EOF

# 5. Atur permission direktori web & efs-data agar dapat ditulis oleh Apache
chown -R apache:apache /var/www/html
chmod -R 775 /var/www/html
chmod -R 775 /var/www/html/efs-data

# 6. Jalankan dan aktifkan web server Apache (httpd)
systemctl start httpd
systemctl enable httpd
