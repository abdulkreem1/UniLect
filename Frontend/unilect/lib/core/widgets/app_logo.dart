import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The UniLect app mark (rounded tile from the brand artwork).
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96, this.heroTag = 'app-logo'});

  final double size;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final image = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B4FC4).withValues(alpha: 0.35),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          semanticLabel: 'UniLect',
        ),
      ),
    );
    return heroTag == null ? image : Hero(tag: heroTag!, child: image);
  }
}

/// Text wordmark in brand colors: "Uni" white/onSurface + "Lect" gradient.
class AppWordmark extends StatelessWidget {
  const AppWordmark({super.key, this.fontSize = 28, this.onDark = false});

  final double fontSize;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontWeight: FontWeight.w700,
      fontSize: fontSize,
      height: 1.1,
      letterSpacing: -0.5,
    );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Uni',
            style: base.copyWith(
              color: onDark
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
          ),
          ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              colors: [Color(0xFF38C6F4), Color(0xFF1E9BF0)],
            ).createShader(r),
            child: Text('Lect', style: base.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
