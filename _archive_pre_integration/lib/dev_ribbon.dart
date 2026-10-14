import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_colors.dart';

/// Always-visible marker that the app is talking to the dev fake backend, so
/// demo data can never be mistaken for real backend functionality.
class DevRibbon extends StatelessWidget {
  const DevRibbon({super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      children: [
        child,
        PositionedDirectional(
          top: 0,
          end: 0,
          child: IgnorePointer(
            child: SafeArea(
              child: Semantics(
                label: context.l10n.devBackendNotice,
                child: Container(
                  margin: const EdgeInsetsDirectional.only(top: 2, end: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    context.l10n.devRibbon,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
