import json
import urllib.parse
import boto3
import os
from datetime import datetime

# Inisialisasi klien S3
s3 = boto3.client('s3')

def lambda_handler(event, context):
    """
    Fungsi AWS Lambda yang dipicu oleh S3 ObjectCreated Event.
    Mengekstrak informasi file dari folder 'uploads/' dan membuat
    file ringkasan metadata berformat JSON ke dalam folder 'processed/'.
    """
    print("Menerima S3 Event:", json.dumps(event))
    processed_files = []

    for record in event.get('Records', []):
        try:
            # 1. Mengambil informasi bucket dan nama file (key)
            bucket_name = record['s3']['bucket']['name']
            raw_key = record['s3']['object']['key']
            object_key = urllib.parse.unquote_plus(raw_key)

            print(f"Memproses objek: {object_key} dari bucket: {bucket_name}")

            # 2. Filter keamanan: Pastikan hanya memproses file di folder 'uploads/'
            # Hindari memproses folder itu sendiri atau file di folder 'processed/' (mencegah loop rekursif)
            if not object_key.startswith('uploads/') or object_key.endswith('/'):
                print(f"Skipping key {object_key}: Bukan file target di dalam 'uploads/'.")
                continue

            filename = os.path.basename(object_key)

            # 3. Ambil metadata objek dari S3
            head_response = s3.head_object(Bucket=bucket_name, Key=object_key)
            file_size_bytes = head_response.get('ContentLength', 0)
            content_type = head_response.get('ContentType', 'unknown')
            last_modified = str(head_response.get('LastModified', datetime.utcnow()))
            etag = head_response.get('ETag', '').strip('"')

            # Ekstrak ekstensi file
            _, ext = os.path.splitext(filename)
            file_ext = ext.lower().replace('.', '') if ext else 'no_extension'

            # 4. Susun laporan analisis metadata
            metadata_summary = {
                "project": "Cloud Computing - Storage & Serverless Pipeline",
                "processed_at_utc": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"),
                "source": {
                    "bucket": bucket_name,
                    "folder": "uploads",
                    "file_name": filename,
                    "full_path": object_key
                },
                "file_attributes": {
                    "size_bytes": file_size_bytes,
                    "size_kb": round(file_size_bytes / 1024, 2),
                    "size_mb": round(file_size_bytes / (1024 * 1024), 4),
                    "extension": file_ext,
                    "content_type": content_type,
                    "etag": etag,
                    "s3_last_modified": last_modified
                },
                "processing_info": {
                    "processed_by": "AWS Lambda (Python 3.12)",
                    "execution_role": "LabRole",
                    "status": "SUCCESS"
                }
            }

            # 5. Tulis hasil analisis ke folder 'processed/' di bucket S3 yang sama
            output_key = f"processed/{filename}_metadata.json"
            
            s3.put_object(
                Bucket=bucket_name,
                Key=output_key,
                Body=json.dumps(metadata_summary, indent=4),
                ContentType='application/json',
                Metadata={
                    'source-file': filename,
                    'generated-by': 'lambda-media-processor'
                }
            )

            print(f"Berhasil membuat metadata JSON: s3://{bucket_name}/{output_key}")
            processed_files.append(output_key)

        except Exception as e:
            print(f"Error memproses file {record.get('s3', {}).get('object', {}).get('key', 'unknown')}: {str(e)}")
            raise e

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Pemrosesan S3 Event oleh Lambda berhasil!',
            'total_files': len(processed_files),
            'processed_files': processed_files
        })
    }
