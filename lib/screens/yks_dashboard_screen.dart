import 'package:flutter/material.dart';

import '../models/dashboard_config.dart';
import 'base_dashboard_screen.dart';

class YksDashboardScreen extends StatelessWidget {
  const YksDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseDashboardScreen(config: DashboardConfig.yks);
  }
}
