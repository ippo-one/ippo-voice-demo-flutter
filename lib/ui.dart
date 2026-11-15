// Shared parts: the colours (same tokens as the web demo), Ippo's mark, buttons, cards and pills.
import 'package:flutter/material.dart';

class C {
  static const ink = Color(0xFF0F1B3D);
  static const ink2 = Color(0xFF3B4562);
  static const muted = Color(0xFF5B6478);
  static const faint = Color(0xFF8A93A8);
  static const line = Color(0xFFE6E9F0);
  static const soft = Color(0xFFF5F6F9);
  static const page = Color(0xFFF3F1EE);
  static const ippo50 = Color(0xFFFFF6EF);
  static const ippo100 = Color(0xFFFFEADB);
  static const ippo300 = Color(0xFFFFB37F);
  static const ippo400 = Color(0xFFFF8F4A);
  static const ippo500 = Color(0xFFFF6B1A);
  static const ippo600 = Color(0xFFEC5608);
  static const ok = Color(0xFF1F8A4C);
  static const okSoft = Color(0xFFE6F5EC);
  static const bad = Color(0xFFD93A2B);
  static const badSoft = Color(0xFFFDECEA);
  static const warn = Color(0xFFB7791F);
  static const warnSoft = Color(0xFFFDF3E2);
}

ThemeData ippoTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: C.ippo500, primary: C.ink, surface: Colors.white),
      scaffoldBackgroundColor: Colors.white,
      textTheme: const TextTheme().apply(bodyColor: C.ink, displayColor: C.ink),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: C.ippo400, width: 2)),
      ),
    );

/// Ippo's mark: an orange orb with three voice bars that move while Ippo talks.
class IppoMark extends StatefulWidget {
  const IppoMark({super.key, this.size = 22, this.live = false});
  final double size;
  final bool live;

  @override
  State<IppoMark> createState() => _IppoMarkState();
}

class _IppoMarkState extends State<IppoMark> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  static const _bars = [0.42, 0.78, 0.55];

  @override
  void initState() {
    super.initState();
    if (widget.live) _t.repeat();
  }

  @override
  void didUpdateWidget(IppoMark old) {
    super.didUpdateWidget(old);
    if (widget.live && !_t.isAnimating) _t.repeat();
    if (!widget.live && _t.isAnimating) _t.stop();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Container(
      width: s,
      height: s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(center: Alignment(-0.36, -0.44), colors: [C.ippo300, C.ippo500, C.ippo600], stops: [0, .55, 1]),
        boxShadow: [BoxShadow(color: C.ippo600.withValues(alpha: .45), blurRadius: s * .3, offset: Offset(0, s * .08))],
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: s * .5,
        height: s * .5,
        child: AnimatedBuilder(
          animation: _t,
          builder: (_, __) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: s * .06),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: widget.live ? _wave(_bars[i], (_t.value + i * .17) % 1) : _bars[i],
                    child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(s))),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  double _wave(double h, double t) {
    // h → 1 → 0.6h → h, like the web mark
    if (t < .33) return h + (1 - h) * (t / .33);
    if (t < .66) return 1 - (1 - h * .6) * ((t - .33) / .33);
    return h * .6 + h * .4 * ((t - .66) / .34);
  }
}

class IppoCard extends StatelessWidget {
  const IppoCard({super.key, required this.child, this.accent = false, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final bool accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent ? C.ippo300 : C.line, width: accent ? 1.5 : 1),
          boxShadow: const [BoxShadow(color: Color(0x0F0F1B3D), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: child,
      );
}

enum BtnTone { ink, ghost, ippo }

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, required this.onPressed, this.tone = BtnTone.ink, this.icon, this.small = false});
  final String label;
  final VoidCallback? onPressed;
  final BtnTone tone;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) { BtnTone.ink => C.ink, BtnTone.ippo => C.ippo500, BtnTone.ghost => Colors.white };
    final fg = tone == BtnTone.ghost ? C.ink : Colors.white;
    return SizedBox(
      height: small ? 36 : 48,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: .35),
          // a disabled ghost button must look disabled too, not just a white one
          disabledForegroundColor: tone == BtnTone.ghost ? C.faint.withValues(alpha: .6) : fg.withValues(alpha: .7),
          side: tone == BtnTone.ghost ? const BorderSide(color: C.line) : null,
          shape: const StadiumBorder(),
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
          textStyle: TextStyle(fontSize: small ? 13 : 15, fontWeight: FontWeight.w600),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: small ? 15 : 18), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }
}

enum PillTone { plain, ok, bad, warn, ippo }

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.tone = PillTone.plain});
  final String text;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.ok => (C.okSoft, C.ok),
      PillTone.bad => (C.badSoft, C.bad),
      PillTone.warn => (C.warnSoft, C.warn),
      PillTone.ippo => (C.ippo50, C.ippo600),
      PillTone.plain => (C.soft, C.ink2),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
      child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

/// The badge on cards backed by a real LoanPilot call.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(99)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 3, backgroundColor: Color(0xFF34C77B)),
          SizedBox(width: 4),
          Text('LIVE · app.ippo.one', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: .3)),
        ]),
      );
}

/// A card title with the LIVE badge on the right.
class CardHead extends StatelessWidget {
  const CardHead(this.title, {super.key, this.live = true});
  final String title;
  final bool live;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          if (live) const LiveBadge(),
        ]),
      );
}

const mutedText = TextStyle(fontSize: 12.5, color: C.muted, height: 1.4);
