# YKS TYT Priority Plan

Bu plan YKS'nin ilk tamamlanacak parcasi olan TYT icin icerik onceligini belirler.

## Priority Mantigi

- `priority = 1`
  Anlamli soru yogunlugu olan, neredeyse her yil sorulan ve ogrenci sonucunu en cok etkileyen konular.
- `priority = 2`
  Duzenli gelen ama ikinci katman agirlikta olan konular.
- `priority = 3`
  Bu ilk TYT seed paketinde kullanilmadi. Daha sonra destekleyici havuz icin eklenebilir.

## Target Question Count

Bu alan her topic icin uzun vadeli hedef soru havuzunu ifade eder.

### Turkce
- Paragraf: `priority 1`, `target_question_count 400`
- Cumlede Anlam: `priority 1`, `target_question_count 250`
- Sozcukte Anlam: `priority 1`, `target_question_count 250`
- Yazim Kurallari ve Noktalama: `priority 2`, `target_question_count 180`
- Sozcuk Turleri ve Cumlenin Ogeleri: `priority 2`, `target_question_count 160`

### Matematik
- Problemler: `priority 1`, `target_question_count 400`
- Temel Kavramlar ve Sayilar: `priority 1`, `target_question_count 280`
- Ucgenler: `priority 1`, `target_question_count 220`
- Fonksiyonlar: `priority 1`, `target_question_count 180`
- Kumeler: `priority 2`, `target_question_count 140`
- Veri ve Istatistik: `priority 2`, `target_question_count 130`
- Olasilik: `priority 2`, `target_question_count 130`

### Fizik
- Isi ve Sicaklik: `priority 1`, `target_question_count 160`
- Kuvvet ve Hareket: `priority 1`, `target_question_count 170`
- Optik: `priority 1`, `target_question_count 150`

### Kimya
- Atom ve Periyodik Sistem: `priority 1`, `target_question_count 150`
- Kimyasal Turler Arasi Etkilesimler: `priority 1`, `target_question_count 140`
- Maddenin Halleri: `priority 2`, `target_question_count 130`
- Karisimlar: `priority 2`, `target_question_count 130`

### Biyoloji
- Canlilarin Temel Bilesenleri: `priority 2`, `target_question_count 130`
- Hucre: `priority 1`, `target_question_count 150`
- Kalitim: `priority 2`, `target_question_count 130`
- Ekosistem: `priority 2`, `target_question_count 120`

### Tarih
- Milli Mucadele ve Ataturk Ilkeleri: `priority 1`, `target_question_count 180`
- Ilk ve Orta Caglarda Turk Dunyasi: `priority 2`, `target_question_count 140`

### Cografya
- Harita Bilgisi: `priority 1`, `target_question_count 180`
- Iklim Bilgisi: `priority 2`, `target_question_count 140`
- Nufus ve Yerlesme: `priority 2`, `target_question_count 130`

### Felsefe
- Bilgi Felsefesi: `priority 2`, `target_question_count 120`
- Ahlak Felsefesi: `priority 2`, `target_question_count 110`

### Din Kulturu
- Bilgi ve Inanc: `priority 2`, `target_question_count 120`
- Ibadetler: `priority 2`, `target_question_count 110`

## SQL Dosyalari

Curriculum seed:
- [supabase_yks_tyt_curriculum_seed.sql](/C:/Users/benli/OneDrive/Desktop/exam_ai_app/supabase_yks_tyt_curriculum_seed.sql)

Ilk 50 job:
- [supabase_yks_tyt_first_50_jobs.sql](/C:/Users/benli/OneDrive/Desktop/exam_ai_app/supabase_yks_tyt_first_50_jobs.sql)

Question generation job tablosu:
- [supabase_question_generation_jobs.sql](/C:/Users/benli/OneDrive/Desktop/exam_ai_app/supabase_question_generation_jobs.sql)

## Uygulama Sirasi

1. TYT curriculum seed SQL calistir.
2. Ilk 50 job SQL calistir.
3. Batch runner ile sorulari uret.
4. UI'da sadece onayli ve kayitli sorulari kullan.
5. Sonra AYT katmanina gec.
