import 'package:flutter/material.dart';

class AuthCard extends StatelessWidget {
  const AuthCard({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final isIOS = platform == TargetPlatform.iOS;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22, isIOS ? 26 : 24, 22, isIOS ? 22 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFE9ECF5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D3A8C).withOpacity(0.10),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: child,
    );
  }
}
