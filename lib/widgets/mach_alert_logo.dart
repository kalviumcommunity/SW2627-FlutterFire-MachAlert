import 'package:flutter/material.dart';

/// Centralized MachAlert branding widget providing the full approved logo
/// or the compact approved ribbon emblem.
class MachAlertLogo extends StatelessWidget {
  /// Whether to render the compact emblem-only variant.
  /// Defaults to `false` (renders the full approved logo).
  final bool compact;

  /// Retained for backwards compatibility with existing call sites.
  final bool light;

  /// Optional width constraint for the logo.
  final double? width;

  /// Optional height constraint for the logo.
  final double? height;

  const MachAlertLogo({
    super.key,
    this.compact = false,
    this.light = false,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width ?? 70,
          maxHeight: height ?? 32,
        ),
        child: Image.asset(
          'assets/branding/machalert_emblem.png',
          width: width,
          height: height ?? 32,
          fit: BoxFit.contain,
          semanticLabel: 'MachAlert Emblem',
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width ?? 280,
        maxHeight: height ?? 80,
      ),
      child: Image.asset(
        'assets/branding/machalert_logo.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
        semanticLabel: 'MachAlert Logo',
      ),
    );
  }
}
