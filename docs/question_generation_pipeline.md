# Question Generation Pipeline

Bu akis kullaniciya gorunmez. Gelistirici veya admin tarafinda calisir.

## 1. Job Tablosu

SQL:
- [supabase_question_generation_jobs.sql](/C:/Users/benli/OneDrive/Desktop/exam_ai_app/supabase_question_generation_jobs.sql)

Amaç:
- hangi konu icin kac soru uretilecegini planlamak
- batch boyutunu belirlemek
- uretilen / eklenen / duplicate / hata sayilarini izlemek

## 2. Runner

Script:
- [question_generation_job_runner.dart](/C:/Users/benli/OneDrive/Desktop/exam_ai_app/tool/question_generation_job_runner.dart)

Amac:
- `pending` durumundaki joblari cekmek
- Gemini ile batch soru uretmek
- JSON formatini dogrulamak
- duplicate kontrolu yapmak
- `questions` ve `question_options` tablolarina yazmak
- job durumunu guncellemek

Gerekli `.env` degiskenleri:
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `GOOGLE_API_KEY`
- `GOOGLE_MODEL`
- `GOOGLE_API_BASE_URL`

## 3. Prompt Sablonlari

### Standart konu testi

```text
Sen Turkiye'deki ogrenciler icin ozgun sinav sorulari ureten uzman bir ogretmensin.

Sinav: YKS
Bolum: TYT
Ders: Matematik
Konu: Problemler
Zorluk: medium
Soru Stili: standard

Birbirinden farkli 10 adet coktan secmeli soru uret.
Her soru 5 secenekli olsun: A, B, C, D, E.
Tek bir dogru cevap olsun.
Sorular tamamen ozgun olsun.
Bilinen cikmis sorulari kopyalama veya yakin turevlerini verme.
Sorular Turkce olsun.
Mufredata uygun olsun.

Yaniti sadece JSON array olarak ver.
```

### Yeni nesil uzun paragraf

```text
Sinav: YKS
Bolum: TYT
Ders: Turkce
Konu: Paragraf
Zorluk: hard
Soru Stili: long_paragraph

Uzun ve yeni nesil dusunme gerektiren 10 ozgun soru uret.
```

### Grafik / tablo yorumlama

```text
Sinav: YKS
Bolum: TYT
Ders: Matematik
Konu: Veri ve Istatistik
Zorluk: medium
Soru Stili: table_interpretation

Tablo veya veri yorumlamaya dayali 10 ozgun soru uret.
```

## 4. DB Insert Akisi

1. `question_generation_jobs` tablosundan `pending` job cekilir.
2. Job verisine gore prompt olusturulur.
3. Gemini'den JSON array soru listesi alinir.
4. Her soru icin:
   - `normalized_stem` hesaplanir
   - ayni `topic_id + normalized_stem` varsa duplicate sayilir
   - yoksa `questions` tablosuna insert edilir
   - sonra `question_options` tablosuna 5 secenek yazilir
5. Job:
   - `generated_count`
   - `inserted_count`
   - `duplicate_count`
   - `failed_count`
   alanlariyla guncellenir

## 5. Ornek Job Insert

```sql
insert into public.question_generation_jobs (
  exam_id,
  subject_id,
  topic_id,
  section_name,
  difficulty,
  question_style,
  target_count,
  batch_size,
  prompt_version,
  notes
)
values (
  'EXAM_UUID',
  'SUBJECT_UUID',
  'TOPIC_UUID',
  'TYT',
  'medium',
  'standard',
  200,
  10,
  'v1',
  'TYT Matematik Problemler ilk batch'
);
```

## 6. Calistirma

Ornek:

```powershell
dart run tool/question_generation_job_runner.dart
```

Not:
- Bu script icin `.env` icinde `SUPABASE_SERVICE_ROLE_KEY` olmali.
- Bu script kullanici uygulamasindan ayridir.
- Uretilen sorular once DB'ye yazilir, sonra ogrenciye servis edilir.
