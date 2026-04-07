alter table if exists public.subjects
  add column if not exists section_name text;

alter table if exists public.topics
  add column if not exists section_name text,
  add column if not exists priority int,
  add column if not exists target_question_count int;

create index if not exists subjects_exam_section_idx
  on public.subjects (exam_id, section_name, name);

create index if not exists topics_subject_section_priority_idx
  on public.topics (subject_id, section_name, priority);

do $$
declare
  yks_exam_id uuid;
begin
  select id
  into yks_exam_id
  from public.exams
  where name = 'YKS'
  limit 1;

  if yks_exam_id is null then
    insert into public.exams (name, description)
    values ('YKS', 'YKS sinavi icin otomatik seed kaydi')
    returning id into yks_exam_id;
  end if;

  update public.subjects
  set section_name = 'TYT'
  where exam_id = yks_exam_id
    and name in ('Turkce', 'Matematik', 'Fizik', 'Kimya')
    and section_name is null;

  insert into public.subjects (exam_id, name, section_name)
  select yks_exam_id, seed.name, 'TYT'
  from (
    values
      ('Turkce'),
      ('Matematik'),
      ('Tarih'),
      ('Cografya'),
      ('Felsefe'),
      ('Din Kulturu'),
      ('Fizik'),
      ('Kimya'),
      ('Biyoloji')
  ) as seed(name)
  where not exists (
    select 1
    from public.subjects s
    where s.exam_id = yks_exam_id
      and s.name = seed.name
      and coalesce(s.section_name, 'TYT') = 'TYT'
  );

  with topic_seed as (
    select *
    from (
      values
        ('Turkce', 'Paragraf', 1, 400),
        ('Turkce', 'Cumlede Anlam', 1, 250),
        ('Turkce', 'Sozcukte Anlam', 1, 250),
        ('Turkce', 'Yazim Kurallari ve Noktalama', 2, 180),
        ('Turkce', 'Sozcuk Turleri ve Cumlenin Ogeleri', 2, 160),

        ('Matematik', 'Problemler', 1, 400),
        ('Matematik', 'Temel Kavramlar ve Sayilar', 1, 280),
        ('Matematik', 'Ucgenler', 1, 220),
        ('Matematik', 'Fonksiyonlar', 1, 180),
        ('Matematik', 'Kumeler', 2, 140),
        ('Matematik', 'Veri ve Istatistik', 2, 130),
        ('Matematik', 'Olasilik', 2, 130),

        ('Fizik', 'Isi ve Sicaklik', 1, 160),
        ('Fizik', 'Kuvvet ve Hareket', 1, 170),
        ('Fizik', 'Optik', 1, 150),

        ('Kimya', 'Atom ve Periyodik Sistem', 1, 150),
        ('Kimya', 'Kimyasal Turler Arasi Etkilesimler', 1, 140),
        ('Kimya', 'Maddenin Halleri', 2, 130),
        ('Kimya', 'Karisimlar', 2, 130),

        ('Biyoloji', 'Canlilarin Temel Bilesenleri', 2, 130),
        ('Biyoloji', 'Hucre', 1, 150),
        ('Biyoloji', 'Kalitim', 2, 130),
        ('Biyoloji', 'Ekosistem', 2, 120),

        ('Tarih', 'Milli Mucadele ve Ataturk Ilkeleri', 1, 180),
        ('Tarih', 'Ilk ve Orta Caglarda Turk Dunyasi', 2, 140),

        ('Cografya', 'Harita Bilgisi', 1, 180),
        ('Cografya', 'Iklim Bilgisi', 2, 140),
        ('Cografya', 'Nufus ve Yerlesme', 2, 130),

        ('Felsefe', 'Bilgi Felsefesi', 2, 120),
        ('Felsefe', 'Ahlak Felsefesi', 2, 110),

        ('Din Kulturu', 'Bilgi ve Inanc', 2, 120),
        ('Din Kulturu', 'Ibadetler', 2, 110)
    ) as seed(subject_name, topic_name, priority, target_question_count)
  )
  update public.topics t
  set section_name = 'TYT',
      priority = seed.priority,
      target_question_count = seed.target_question_count
  from topic_seed seed
  join public.subjects s
    on s.exam_id = yks_exam_id
   and s.name = seed.subject_name
   and s.section_name = 'TYT'
  where t.subject_id = s.id
    and t.name = seed.topic_name;

  insert into public.topics (
    subject_id,
    name,
    section_name,
    priority,
    target_question_count
  )
  select
    s.id,
    seed.topic_name,
    'TYT',
    seed.priority,
    seed.target_question_count
  from (
    values
      ('Turkce', 'Paragraf', 1, 400),
      ('Turkce', 'Cumlede Anlam', 1, 250),
      ('Turkce', 'Sozcukte Anlam', 1, 250),
      ('Turkce', 'Yazim Kurallari ve Noktalama', 2, 180),
      ('Turkce', 'Sozcuk Turleri ve Cumlenin Ogeleri', 2, 160),

      ('Matematik', 'Problemler', 1, 400),
      ('Matematik', 'Temel Kavramlar ve Sayilar', 1, 280),
      ('Matematik', 'Ucgenler', 1, 220),
      ('Matematik', 'Fonksiyonlar', 1, 180),
      ('Matematik', 'Kumeler', 2, 140),
      ('Matematik', 'Veri ve Istatistik', 2, 130),
      ('Matematik', 'Olasilik', 2, 130),

      ('Fizik', 'Isi ve Sicaklik', 1, 160),
      ('Fizik', 'Kuvvet ve Hareket', 1, 170),
      ('Fizik', 'Optik', 1, 150),

      ('Kimya', 'Atom ve Periyodik Sistem', 1, 150),
      ('Kimya', 'Kimyasal Turler Arasi Etkilesimler', 1, 140),
      ('Kimya', 'Maddenin Halleri', 2, 130),
      ('Kimya', 'Karisimlar', 2, 130),

      ('Biyoloji', 'Canlilarin Temel Bilesenleri', 2, 130),
      ('Biyoloji', 'Hucre', 1, 150),
      ('Biyoloji', 'Kalitim', 2, 130),
      ('Biyoloji', 'Ekosistem', 2, 120),

      ('Tarih', 'Milli Mucadele ve Ataturk Ilkeleri', 1, 180),
      ('Tarih', 'Ilk ve Orta Caglarda Turk Dunyasi', 2, 140),

      ('Cografya', 'Harita Bilgisi', 1, 180),
      ('Cografya', 'Iklim Bilgisi', 2, 140),
      ('Cografya', 'Nufus ve Yerlesme', 2, 130),

      ('Felsefe', 'Bilgi Felsefesi', 2, 120),
      ('Felsefe', 'Ahlak Felsefesi', 2, 110),

      ('Din Kulturu', 'Bilgi ve Inanc', 2, 120),
      ('Din Kulturu', 'Ibadetler', 2, 110)
  ) as seed(subject_name, topic_name, priority, target_question_count)
  join public.subjects s
    on s.exam_id = yks_exam_id
   and s.name = seed.subject_name
   and s.section_name = 'TYT'
  where not exists (
    select 1
    from public.topics t
    where t.subject_id = s.id
      and t.name = seed.topic_name
  );
end $$;
