import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'exam_type.dart';

/// Describes a single action tile shown on the dashboard (e.g. "Hızlı Çöz").
class DashboardActionTile {
  const DashboardActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    this.routeId,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color tint;

  /// An identifier used by the dashboard screen to decide which screen to
  /// navigate to when the tile is tapped.
  final String? routeId;
}

/// YKS supports two tracks: TYT (active) and AYT (placeholder for now).
enum YksTrack { tyt, ayt }

/// Holds a section of actions that can be gated by [YksTrack] in the future.
class DashboardSection {
  const DashboardSection({
    required this.label,
    required this.actions,
    this.yksTrack,
  });

  final String label;
  final List<DashboardActionTile> actions;

  /// When non-null the section is only visible for that track.
  final YksTrack? yksTrack;
}

/// Per-exam configuration consumed by the dashboard screen.
class DashboardConfig {
  const DashboardConfig({
    required this.examType,
    required this.themeGradient,
    required this.sections,
    this.bottomLabels = _defaultBottomLabels,
  });

  final ExamType examType;
  final List<Color> themeGradient;
  final List<DashboardSection> sections;
  final List<String> bottomLabels;

  static const _defaultBottomLabels = [
    'Panel',
    'Pratik',
    'Deneme',
    'Analiz',
    'Profil',
  ];

  /// Flat list of all actions from every section.
  List<DashboardActionTile> get allActions =>
      sections.expand((s) => s.actions).toList();

  // ───────────────── pre-built configs ─────────────────

  static final yks = DashboardConfig(
    examType: ExamType.yks,
    themeGradient: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
    sections: [
      DashboardSection(
        label: 'TYT',
        yksTrack: YksTrack.tyt,
        actions: [
          const DashboardActionTile(
            icon: CupertinoIcons.bolt_fill,
            title: 'Hızlı Çöz',
            subtitle: 'Karışık sorular',
            tint: Color(0xFFE0ECFF),
            routeId: 'quick_solve',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.scope,
            title: 'Konu Testi',
            subtitle: 'Tek konu odaklı',
            tint: Color(0xFFE7F8EE),
            routeId: 'topic_test',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.doc_text_search,
            title: 'Mini Deneme',
            subtitle: 'Hızlı ölçüm',
            tint: Color(0xFFFFF2E2),
            routeId: 'mini_mock',
          ),
        ],
      ),
      DashboardSection(
        label: 'AYT',
        yksTrack: YksTrack.ayt,
        actions: [
          const DashboardActionTile(
            icon: CupertinoIcons.book_fill,
            title: 'AYT Hazırlık',
            subtitle: 'Yakında aktif olacak',
            tint: Color(0xFFE8E0FF),
            routeId: 'ayt_placeholder',
          ),
        ],
      ),
    ],
  );

  static final lgs = DashboardConfig(
    examType: ExamType.lgs,
    themeGradient: const [Color(0xFF0F766E), Color(0xFF34D399)],
    sections: [
      DashboardSection(
        label: 'LGS',
        actions: [
          const DashboardActionTile(
            icon: CupertinoIcons.bolt_fill,
            title: 'Hızlı Çöz',
            subtitle: 'Karışık sorular',
            tint: Color(0xFFE0ECFF),
            routeId: 'quick_solve',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.scope,
            title: 'Konu Testi',
            subtitle: 'Tek konu odaklı',
            tint: Color(0xFFE7F8EE),
            routeId: 'topic_test',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.doc_text_search,
            title: 'Mini Deneme',
            subtitle: 'Hızlı ölçüm',
            tint: Color(0xFFFFF2E2),
            routeId: 'mini_mock',
          ),
        ],
      ),
    ],
  );

  static final kpss = DashboardConfig(
    examType: ExamType.kpss,
    themeGradient: const [Color(0xFFF59E0B), Color(0xFFF97316)],
    sections: [
      DashboardSection(
        label: 'KPSS',
        actions: [
          const DashboardActionTile(
            icon: CupertinoIcons.bolt_fill,
            title: 'Hızlı Çöz',
            subtitle: 'Karışık sorular',
            tint: Color(0xFFE0ECFF),
            routeId: 'quick_solve',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.scope,
            title: 'Konu Testi',
            subtitle: 'Tek konu odaklı',
            tint: Color(0xFFE7F8EE),
            routeId: 'topic_test',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.doc_text_search,
            title: 'Mini Deneme',
            subtitle: 'Hızlı ölçüm',
            tint: Color(0xFFFFF2E2),
            routeId: 'mini_mock',
          ),
        ],
      ),
    ],
  );

  static final ales = DashboardConfig(
    examType: ExamType.ales,
    themeGradient: const [Color(0xFF7C3AED), Color(0xFFA78BFA)],
    sections: [
      DashboardSection(
        label: 'ALES',
        actions: [
          const DashboardActionTile(
            icon: CupertinoIcons.bolt_fill,
            title: 'Hızlı Çöz',
            subtitle: 'Karışık sorular',
            tint: Color(0xFFE0ECFF),
            routeId: 'quick_solve',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.scope,
            title: 'Konu Testi',
            subtitle: 'Tek konu odaklı',
            tint: Color(0xFFE7F8EE),
            routeId: 'topic_test',
          ),
          const DashboardActionTile(
            icon: CupertinoIcons.doc_text_search,
            title: 'Mini Deneme',
            subtitle: 'Hızlı ölçüm',
            tint: Color(0xFFFFF2E2),
            routeId: 'mini_mock',
          ),
        ],
      ),
    ],
  );

  /// Resolve a config for the given exam title.
  static DashboardConfig forExamTitle(String title) {
    switch (title.toUpperCase()) {
      case 'YKS':
        return yks;
      case 'LGS':
        return lgs;
      case 'KPSS':
        return kpss;
      case 'ALES':
        return ales;
      default:
        return yks;
    }
  }
}
