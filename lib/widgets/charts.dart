import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/formatters.dart' as fmt;
import '../core/theme.dart';
import '../domain/models.dart';

/// Peer percentiles as a horizontal scale with the subject marked.
class PeerDistributionChart extends StatelessWidget {
  const PeerDistributionChart({super.key, required this.peers, required this.subject});
  final PeerDistribution peers;
  final double subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 64,
        child: CustomPaint(
          size: const Size(double.infinity, 64),
          painter: _PeerPainter(
            peers: peers,
            subject: subject,
            track: theme.colorScheme.surfaceContainerHighest,
            band: theme.colorScheme.primary.withValues(alpha: 0.25),
            tick: theme.colorScheme.onSurfaceVariant,
            marker: tierColor(Tier.peerOutlier, theme.colorScheme),
            labelStyle: theme.textTheme.labelSmall!.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        '${peers.peerGroup} · ${fmt.count(peers.peerCount)} peers · ${peers.unit}',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    ]);
  }
}

class _PeerPainter extends CustomPainter {
  _PeerPainter({
    required this.peers,
    required this.subject,
    required this.track,
    required this.band,
    required this.tick,
    required this.marker,
    required this.labelStyle,
  });
  final PeerDistribution peers;
  final double subject;
  final Color track, band, tick, marker;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 6.0, padR = 6.0;
    final w = size.width - padL - padR;
    final maxV = [peers.p99 * 1.15, subject * 1.1].reduce((a, b) => a > b ? a : b);
    double x(double v) => padL + (v / maxV).clamp(0, 1) * w;
    const y = 26.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(padL, y - 5, w, 10), const Radius.circular(5)),
      Paint()..color = track,
    );
    // p50 to p95 band
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(x(peers.p50), y - 5, x(peers.p95), y + 5), const Radius.circular(5)),
      Paint()..color = band,
    );
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 1.5;
    for (final (label, v) in [('p50', peers.p50), ('p90', peers.p90), ('p99', peers.p99)]) {
      final px = x(v);
      canvas.drawLine(Offset(px, y - 9), Offset(px, y + 9), tickPaint);
      final tp = TextPainter(text: TextSpan(text: label, style: labelStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(px - tp.width / 2, y + 12));
    }
    // subject marker
    final sx = x(subject);
    canvas.drawCircle(Offset(sx, y), 7, Paint()..color = marker);
    canvas.drawCircle(Offset(sx, y), 7, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
    final tp = TextPainter(
      text: TextSpan(text: 'subject ${subject.toStringAsFixed(1)}', style: labelStyle.copyWith(color: marker, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    final lx = (sx - tp.width / 2).clamp(0.0, size.width - tp.width);
    tp.paint(canvas, Offset(lx, 0));
  }

  @override
  bool shouldRepaint(covariant _PeerPainter old) => old.subject != subject || old.peers != peers;
}

/// Lift over base rate with its 95% interval, on a log scale.
/// An interval reaching below 1x means the rule may be no better than chance.
class LiftChart extends StatelessWidget {
  const LiftChart({super.key, required this.rows});
  final List<BacktestRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              SizedBox(
                width: 118,
                child: Text(r.rule, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 22,
                  child: CustomPaint(
                    painter: _LiftPainter(
                      row: r,
                      maxLift: 250,
                      track: theme.colorScheme.surfaceContainerHighest,
                      bar: r.significant ? theme.colorScheme.primary : theme.colorScheme.outline,
                      chance: tierColor(Tier.hardRule, theme.colorScheme),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 36,
                child: Text(fmt.lift(r.lift),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Container(width: 2, height: 12, color: tierColor(Tier.hardRule, theme.colorScheme)),
            const SizedBox(width: 6),
            Text('1x = chance. Grey bars have an interval that reaches below 1x.',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ]),
        ),
      ],
    );
  }
}

class _LiftPainter extends CustomPainter {
  _LiftPainter({required this.row, required this.maxLift, required this.track, required this.bar, required this.chance});
  final BacktestRow row;
  final double maxLift;
  final Color track, bar, chance;

  double _x(double v, double w) {
    // log scale from 0.3x to maxLift
    const minV = 0.3;
    final lv = (v.clamp(minV, maxLift));
    final t = (_ln(lv) - _ln(minV)) / (_ln(maxLift) - _ln(minV));
    return t * w;
  }

  static double _ln(double v) => math.log(v);

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, midY - 3, size.width, 6), const Radius.circular(3)),
      Paint()..color = track,
    );
    final x1 = _x(1, size.width);
    canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), Paint()..color = chance..strokeWidth = 1.5);
    final lo = _x(row.liftLow, size.width);
    final hi = _x(row.liftHigh, size.width);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(lo, midY - 3, hi, midY + 3), const Radius.circular(3)),
      Paint()..color = bar.withValues(alpha: 0.35),
    );
    final px = _x(row.lift, size.width);
    canvas.drawCircle(Offset(px, midY), 6, Paint()..color = bar);
  }

  @override
  bool shouldRepaint(covariant _LiftPainter old) => old.row != row;
}
