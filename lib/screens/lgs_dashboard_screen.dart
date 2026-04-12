import 'package:flutter/material.dart';

import '../models/dashboard_config.dart';
import 'base_dashboard_screen.dart';

class LgsDashboardScreen extends StatelessWidget {
  const LgsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseDashboardScreen(config: DashboardConfig.lgs);
  }
}
