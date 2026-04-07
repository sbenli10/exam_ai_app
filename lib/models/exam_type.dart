class ExamType {
  const ExamType({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  static const yks = ExamType(
    title: 'YKS',
    description: 'TYT ve AYT odaklı akıllı sınav hazırlığı.',
  );

  static const lgs = ExamType(
    title: 'LGS',
    description: 'Ortaokul düzeyine uygun hedefli çalışma planı.',
  );

  static const kpss = ExamType(
    title: 'KPSS',
    description: 'Genel yetenek ve genel kültür odaklı hazırlık.',
  );

  static const ales = ExamType(
    title: 'ALES',
    description: 'Sayısal ve sözel mantık performansını güçlendir.',
  );

  static const all = [yks, lgs, kpss, ales];

  static ExamType fromTitle(String title) {
    return all.firstWhere(
      (exam) => exam.title.toUpperCase() == title.toUpperCase(),
      orElse: () => yks,
    );
  }
}
