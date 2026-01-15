import json
import subprocess
import os

def fix_storage_cors():
    # 1. CORS yapılandırma dosyasını oluştur
    cors_config = [
        {
            "origin": ["*"],
            "method": ["GET", "HEAD", "PUT", "POST", "DELETE"],
            "responseHeader": ["Content-Type"],
            "maxAgeSeconds": 3600
        }
    ]
    
    config_file = "cors.json"
    with open(config_file, "w") as f:
        json.dump(cors_config, f)
    
    print(f"✅ {config_file} oluşturuldu.")
    
    # 2. Kullanıcıdan bucket adını al (ya da varsayılanı kullan)
    bucket_url = "gs://mentaliq-app.firebasestorage.app"
    
    print(f"🚀 {bucket_url} için CORS ayarları yapılıyor...")
    
    try:
        # gsutil komutunu çalıştır
        subprocess.run(["gsutil", "cors", "set", config_file, bucket_url], check=True)
        print("\n🎉 CORS ayarları başarıyla tamamlandı! Resimler artık Flutter Web üzerinde görünebilir.")
        print("💡 Değişikliklerin yansıması için uygulamada sayfayı yenilemeyi unutma.")
    except Exception as e:
        print("\n❌ gsutil komutu çalıştırılamadı. Lütfen Google Cloud SDK'nın (gsutil) yüklü olduğundan emin ol.")
        print(f"Hata detayı: {e}")
        print("\nAlternatif: Firebase Console'dan (Google Cloud Console üzerinden) manuel olarak da yapabilirsin.")
    finally:
        # Geçici dosyayı sil
        if os.path.exists(config_file):
            os.remove(config_file)

if __name__ == "__main__":
    fix_storage_cors()
