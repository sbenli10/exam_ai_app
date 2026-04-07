with yks_exam as (
  select id
  from public.exams
  where name = 'YKS'
  limit 1
),
topic_ref as (
  select
    e.id as exam_id,
    s.id as subject_id,
    s.name as subject_name,
    t.id as topic_id,
    t.name as topic_name,
    t.priority,
    t.target_question_count
  from yks_exam e
  join public.subjects s
    on s.exam_id = e.id
   and s.section_name = 'TYT'
  join public.topics t
    on t.subject_id = s.id
   and t.section_name = 'TYT'
),
job_seed as (
  select *
  from (
    values
      ('Turkce', 'Paragraf', 'medium', 'standard', 80, 10, 'TYT Turkce Paragraf medium standard'),
      ('Turkce', 'Cumlede Anlam', 'medium', 'standard', 60, 10, 'TYT Turkce Cumlede Anlam medium standard'),
      ('Turkce', 'Sozcukte Anlam', 'medium', 'standard', 60, 10, 'TYT Turkce Sozcukte Anlam medium standard'),
      ('Turkce', 'Yazim Kurallari ve Noktalama', 'medium', 'standard', 40, 10, 'TYT Turkce Yazim Kurallari ve Noktalama medium standard'),
      ('Turkce', 'Sozcuk Turleri ve Cumlenin Ogeleri', 'medium', 'standard', 40, 10, 'TYT Turkce Sozcuk Turleri ve Cumlenin Ogeleri medium standard'),

      ('Matematik', 'Problemler', 'medium', 'standard', 80, 10, 'TYT Matematik Problemler medium standard'),
      ('Matematik', 'Temel Kavramlar ve Sayilar', 'medium', 'standard', 60, 10, 'TYT Matematik Temel Kavramlar ve Sayilar medium standard'),
      ('Matematik', 'Ucgenler', 'medium', 'standard', 50, 10, 'TYT Matematik Ucgenler medium standard'),
      ('Matematik', 'Fonksiyonlar', 'medium', 'standard', 45, 10, 'TYT Matematik Fonksiyonlar medium standard'),
      ('Matematik', 'Kumeler', 'medium', 'standard', 35, 10, 'TYT Matematik Kumeler medium standard'),
      ('Matematik', 'Veri ve Istatistik', 'medium', 'standard', 35, 10, 'TYT Matematik Veri ve Istatistik medium standard'),
      ('Matematik', 'Olasilik', 'medium', 'standard', 35, 10, 'TYT Matematik Olasilik medium standard'),

      ('Fizik', 'Isi ve Sicaklik', 'medium', 'standard', 40, 10, 'TYT Fizik Isi ve Sicaklik medium standard'),
      ('Fizik', 'Kuvvet ve Hareket', 'medium', 'standard', 40, 10, 'TYT Fizik Kuvvet ve Hareket medium standard'),
      ('Fizik', 'Optik', 'medium', 'standard', 35, 10, 'TYT Fizik Optik medium standard'),

      ('Kimya', 'Atom ve Periyodik Sistem', 'medium', 'standard', 35, 10, 'TYT Kimya Atom ve Periyodik Sistem medium standard'),
      ('Kimya', 'Kimyasal Turler Arasi Etkilesimler', 'medium', 'standard', 35, 10, 'TYT Kimya Kimyasal Turler Arasi Etkilesimler medium standard'),
      ('Kimya', 'Maddenin Halleri', 'medium', 'standard', 30, 10, 'TYT Kimya Maddenin Halleri medium standard'),
      ('Kimya', 'Karisimlar', 'medium', 'standard', 30, 10, 'TYT Kimya Karisimlar medium standard'),

      ('Biyoloji', 'Canlilarin Temel Bilesenleri', 'medium', 'standard', 30, 10, 'TYT Biyoloji Canlilarin Temel Bilesenleri medium standard'),
      ('Biyoloji', 'Hucre', 'medium', 'standard', 35, 10, 'TYT Biyoloji Hucre medium standard'),
      ('Biyoloji', 'Kalitim', 'medium', 'standard', 30, 10, 'TYT Biyoloji Kalitim medium standard'),
      ('Biyoloji', 'Ekosistem', 'medium', 'standard', 30, 10, 'TYT Biyoloji Ekosistem medium standard'),

      ('Tarih', 'Milli Mucadele ve Ataturk Ilkeleri', 'medium', 'standard', 45, 10, 'TYT Tarih Milli Mucadele ve Ataturk Ilkeleri medium standard'),
      ('Tarih', 'Ilk ve Orta Caglarda Turk Dunyasi', 'medium', 'standard', 35, 10, 'TYT Tarih Ilk ve Orta Caglarda Turk Dunyasi medium standard'),

      ('Cografya', 'Harita Bilgisi', 'medium', 'standard', 45, 10, 'TYT Cografya Harita Bilgisi medium standard'),
      ('Cografya', 'Iklim Bilgisi', 'medium', 'standard', 35, 10, 'TYT Cografya Iklim Bilgisi medium standard'),
      ('Cografya', 'Nufus ve Yerlesme', 'medium', 'standard', 30, 10, 'TYT Cografya Nufus ve Yerlesme medium standard'),

      ('Felsefe', 'Bilgi Felsefesi', 'medium', 'standard', 25, 10, 'TYT Felsefe Bilgi Felsefesi medium standard'),
      ('Felsefe', 'Ahlak Felsefesi', 'medium', 'standard', 25, 10, 'TYT Felsefe Ahlak Felsefesi medium standard'),

      ('Din Kulturu', 'Bilgi ve Inanc', 'medium', 'standard', 25, 10, 'TYT Din Kulturu Bilgi ve Inanc medium standard'),
      ('Din Kulturu', 'Ibadetler', 'medium', 'standard', 25, 10, 'TYT Din Kulturu Ibadetler medium standard'),

      ('Turkce', 'Paragraf', 'easy', 'short_drill', 60, 10, 'TYT Turkce Paragraf easy short drill'),
      ('Turkce', 'Paragraf', 'hard', 'long_paragraph', 60, 10, 'TYT Turkce Paragraf hard long paragraph'),
      ('Turkce', 'Cumlede Anlam', 'easy', 'short_drill', 40, 10, 'TYT Turkce Cumlede Anlam easy short drill'),
      ('Turkce', 'Sozcukte Anlam', 'easy', 'short_drill', 40, 10, 'TYT Turkce Sozcukte Anlam easy short drill'),

      ('Matematik', 'Problemler', 'easy', 'standard', 60, 10, 'TYT Matematik Problemler easy standard'),
      ('Matematik', 'Problemler', 'hard', 'new_generation', 60, 10, 'TYT Matematik Problemler hard new generation'),
      ('Matematik', 'Temel Kavramlar ve Sayilar', 'easy', 'short_drill', 50, 10, 'TYT Matematik Temel Kavramlar easy short drill'),
      ('Matematik', 'Ucgenler', 'hard', 'new_generation', 40, 10, 'TYT Matematik Ucgenler hard new generation'),
      ('Matematik', 'Fonksiyonlar', 'hard', 'new_generation', 35, 10, 'TYT Matematik Fonksiyonlar hard new generation'),

      ('Fizik', 'Isi ve Sicaklik', 'easy', 'standard', 30, 10, 'TYT Fizik Isi ve Sicaklik easy standard'),
      ('Fizik', 'Kuvvet ve Hareket', 'hard', 'new_generation', 30, 10, 'TYT Fizik Kuvvet ve Hareket hard new generation'),
      ('Kimya', 'Atom ve Periyodik Sistem', 'easy', 'standard', 30, 10, 'TYT Kimya Atom ve Periyodik Sistem easy standard'),
      ('Biyoloji', 'Hucre', 'hard', 'new_generation', 30, 10, 'TYT Biyoloji Hucre hard new generation'),
      ('Tarih', 'Milli Mucadele ve Ataturk Ilkeleri', 'hard', 'new_generation', 35, 10, 'TYT Tarih Milli Mucadele hard new generation'),
      ('Cografya', 'Harita Bilgisi', 'easy', 'standard', 30, 10, 'TYT Cografya Harita Bilgisi easy standard'),

      ('Matematik', 'Problemler', 'medium', 'table_interpretation', 40, 10, 'TYT Matematik Problemler medium table interpretation'),
      ('Matematik', 'Veri ve Istatistik', 'medium', 'table_interpretation', 35, 10, 'TYT Matematik Veri ve Istatistik medium table interpretation'),
      ('Matematik', 'Olasilik', 'hard', 'new_generation', 30, 10, 'TYT Matematik Olasilik hard new generation')
  ) as seed(subject_name, topic_name, difficulty, question_style, target_count, batch_size, notes)
)
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
  notes,
  status
)
select
  topic_ref.exam_id,
  topic_ref.subject_id,
  topic_ref.topic_id,
  'TYT',
  job_seed.difficulty,
  job_seed.question_style,
  job_seed.target_count,
  job_seed.batch_size,
  'v1',
  job_seed.notes,
  'pending'
from job_seed
join topic_ref
  on topic_ref.subject_name = job_seed.subject_name
 and topic_ref.topic_name = job_seed.topic_name
where not exists (
  select 1
  from public.question_generation_jobs j
  where j.notes = job_seed.notes
);
