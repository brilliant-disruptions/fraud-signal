import 'package:flutter/material.dart';

import '../domain/models.dart';

/// Deep navy with an amber accent: serious, legible, and calm. Risk is shown
/// through tier color, never through alarm colors on the chrome itself.
class AppTheme {
  static const seed = Color(0xFF1B2A4A);
  static const amber = Color(0xFFD08C1D);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness, secondary: amber);
    final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF5F6FA) : const Color(0xFF0F1420),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: base.textTheme.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(base.textTheme.labelSmall),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
    );
  }
}

/// Tier colors: Tier 1 is the strongest signal and gets the deepest red;
/// Tier 3 corroborates only and stays neutral.
Color tierColor(Tier tier, ColorScheme scheme) => switch (tier) {
      Tier.hardRule => const Color(0xFFB3261E),
      Tier.peerOutlier => AppTheme.amber,
      Tier.link => scheme.outline,
    };

Color statusColor(LeadStatus status, ColorScheme scheme) => switch (status) {
      LeadStatus.watchList => scheme.outline,
      LeadStatus.pendingReview => AppTheme.amber,
      LeadStatus.signedOff => const Color(0xFF2E7D32),
      LeadStatus.licensed => scheme.primary,
      LeadStatus.reserved => const Color(0xFF6A1B9A),
      LeadStatus.closed => scheme.outlineVariant,
    };

Color verdictColor(AuditVerdict v, ColorScheme scheme) => switch (v) {
      AuditVerdict.pass => const Color(0xFF2E7D32),
      AuditVerdict.watch => AppTheme.amber,
      AuditVerdict.fail => const Color(0xFFB3261E),
    };
