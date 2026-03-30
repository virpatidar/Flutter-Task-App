import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppTheme.pageGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -30,
            child: _GlowOrb(
              size: 220,
              color: AppTheme.accentSoft.withOpacity(0.6),
            ),
          ),
          Positioned(
            top: 180,
            left: -80,
            child: _GlowOrb(
              size: 180,
              color: const Color(0xFFAED8E6).withOpacity(0.45),
            ),
          ),
          Positioned(
            bottom: -100,
            right: 30,
            child: _GlowOrb(
              size: 240,
              color: const Color(0xFFCFE6C7).withOpacity(0.5),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}
