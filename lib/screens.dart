// The four screens: consent (the app's entry), the call with Ippo, the lender's page, and My loans.
import 'package:flutter/material.dart';

import 'cards.dart';
import 'flow.dart';
import 'ui.dart';

class EntryScreen extends StatelessWidget {
  const EntryScreen(this.f, {super.key});
  final IppoFlow f;

  static const _rows = [
    (Icons.badge_outlined, 'Your PAN', 'To confirm it’s you'),
    (Icons.receipt_long_outlined, 'Credit Report', 'How you’ve repaid loans and card bills'),
    (Icons.description_outlined, 'Bank Statement', 'To check income, fraud and risk'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFF3EA), Colors.white], stops: [0, .45]),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Center(child: IppoMark(size: 72, live: true)),
                const SizedBox(height: 20),
                const Text('Get a Personal Loan', textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.5)),
                const SizedBox(height: 8),
                const Text('Tell Ippo how much you need, by voice or typing. You’ll see your real offer and choose whether to apply.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: C.muted, height: 1.5)),
                const SizedBox(height: 28),
                const Text('What lenders see, and why', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (final (icon, t, s) in _rows)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line)),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: C.ippo50, borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, size: 20, color: C.ippo600),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(s, style: const TextStyle(fontSize: 12, color: C.muted)),
                        ]),
                      ),
                      const CircleAvatar(radius: 12, backgroundColor: C.ok, child: Icon(Icons.check, size: 14, color: Colors.white)),
                    ]),
                  ),
                const Spacer(),
                const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.shield_outlined, size: 16, color: C.ippo600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'By continuing, you allow IppoPay to get your credit report and share these details with its partner lenders for this loan.',
                      style: TextStyle(fontSize: 11.5, color: C.muted, height: 1.5),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Btn('Agree and Continue', onPressed: f.start),
              ]),
            ),
          ),
        ),
      );
}

class ChatScreen extends StatefulWidget {
  const ChatScreen(this.f, {super.key});
  final IppoFlow f;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();
  final _typed = TextEditingController();
  bool _typing = false;
  int _seen = 0;

  @override
  void dispose() {
    _scroll.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  String get _statusLine {
    final f = widget.f;
    return switch (f.status) {
      LiveStatus.connecting => 'Connecting…',
      LiveStatus.error => 'Couldn’t reach Ippo',
      LiveStatus.idle => 'Call ended',
      LiveStatus.on => f.botSpeaking ? 'Speaking' : (f.thinking ? 'Thinking…' : (f.muted ? 'Muted' : 'Listening')),
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.f;
    final size = f.turns.fold<int>(0, (n, t) => n + (t.said?.length ?? 0) + (t.step != null ? 1 : 0)) + f.turns.length;
    if (size != _seen) {
      _seen = size;
      _toBottom();
    }
    final active = f.activeTurn;
    return Scaffold(
      backgroundColor: C.soft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 16,
        automaticallyImplyLeading: false,
        title: Row(children: [
          IppoMark(size: 32, live: f.botSpeaking),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Ippo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_statusLine, style: TextStyle(fontSize: 12, color: f.status == LiveStatus.error ? C.bad : C.muted)),
          ]),
        ]),
        actions: [
          if (f.status == LiveStatus.on || f.status == LiveStatus.connecting)
            IconButton(tooltip: 'End call', onPressed: f.end, icon: const Icon(Icons.call_end, color: C.bad))
          else
            IconButton(tooltip: 'Start again', onPressed: f.restart, icon: const Icon(Icons.restart_alt)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            children: [
              for (final t in f.turns) ..._turn(f, t, t.key == active),
              if (f.status == LiveStatus.error && f.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: IppoCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Couldn’t reach Ippo', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(f.error!, style: const TextStyle(fontSize: 12.5, color: C.bad)),
                      const SizedBox(height: 10),
                      Btn('Try again', small: true, onPressed: f.start),
                    ]),
                  ),
                ),
              if (f.status == LiveStatus.idle && f.turns.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Center(child: Text('Call ended', style: TextStyle(fontSize: 12, color: C.faint))),
                ),
            ],
          ),
        ),
        _bottomBar(f),
      ]),
    );
  }

  List<Widget> _turn(IppoFlow f, Turn t, bool active) => [
        if (t.user != null) _userBubble(t.user!),
        if (t.said != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, right: 36),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: IppoMark(size: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(t.said!, style: TextStyle(fontSize: 15, height: 1.45, color: t.saying ? C.ink2 : C.ink)),
              ),
            ]),
          ),
        if (t.step != null) Padding(padding: const EdgeInsets.only(bottom: 10, left: 30), child: stepCard(f, t, active: active)),
      ];

  Widget _userBubble(UserBit u) {
    if (u.kind == 'note') {
      final tone = switch (u.tone) { 'ok' => PillTone.ok, 'bad' => PillTone.bad, _ => PillTone.plain };
      return Padding(padding: const EdgeInsets.only(bottom: 10), child: Center(child: Pill(u.text, tone: tone)));
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: C.ink,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
        ),
        child: u.kind == 'file'
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.picture_as_pdf_outlined, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(u.text, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    if (u.note != null) Text(u.note!, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
                  ]),
                ),
              ])
            : Text(u.text,
                style: TextStyle(color: Colors.white, fontSize: 15, fontFamily: u.mono ? 'monospace' : null, letterSpacing: u.mono ? 2 : null)),
      ),
    );
  }

  Widget _bottomBar(IppoFlow f) {
    final on = f.status == LiveStatus.on;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      // typing only makes sense in a live call; after it ends, the bar offers "call again"
      child: _typing && on
          ? Row(children: [
              Expanded(
                child: TextField(
                  controller: _typed,
                  autofocus: true,
                  enabled: on,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendTyped(f),
                  decoration: const InputDecoration(hintText: 'Type to Ippo'),
                ),
              ),
              IconButton(onPressed: on ? () => _sendTyped(f) : null, icon: const Icon(Icons.send, color: C.ippo600)),
              IconButton(onPressed: () => setState(() => _typing = false), icon: const Icon(Icons.mic_none)),
            ])
          : Row(children: [
              IconButton(onPressed: on ? () => setState(() => _typing = true) : null, icon: const Icon(Icons.keyboard_outlined), tooltip: 'Type instead'),
              const Spacer(),
              GestureDetector(
                onTap: on ? () => f.setMuted(!f.muted) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !on ? C.line : (f.muted ? C.ink : C.ippo500),
                    boxShadow: on && !f.muted ? [BoxShadow(color: C.ippo500.withValues(alpha: .4), blurRadius: 16, spreadRadius: 2)] : null,
                  ),
                  child: Icon(f.muted ? Icons.mic_off : Icons.mic, color: Colors.white, size: 28),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: on ? f.end : (f.status == LiveStatus.connecting ? null : f.start),
                icon: Icon(on ? Icons.call_end : Icons.call, color: on ? C.bad : C.ok),
                tooltip: on ? 'End call' : 'Call Ippo again',
              ),
            ]),
    );
  }

  void _sendTyped(IppoFlow f) {
    final text = _typed.text.trim();
    if (text.isEmpty) return;
    _typed.clear();
    f.tap(UserBit.say(text));
  }
}

/// The lender's own page, opened by Ippo (show_step "lender") with the real offer.
class LenderScreen extends StatelessWidget {
  const LenderScreen(this.f, {super.key});
  final IppoFlow f;

  @override
  Widget build(BuildContext context) {
    final o = f.offer?['offer'] as Map<String, dynamic>?;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.close), onPressed: f.lenderClosed),
        title: const Text('Partner lender', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text("You're applying for", style: TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 4),
            Text(o == null ? 'Your loan' : inr(o['amount'] as num), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.6)),
            if (o != null)
              Text('${inr(o['emi'] as num?)} a month for ${o['tenure']} months · ${(((o['rate'] as num?) ?? 0) * 1000).round() / 10}% a year',
                  style: const TextStyle(fontSize: 13, color: C.muted)),
            const SizedBox(height: 20),
            const IppoCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Shared by IppoPay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 6),
                Text('PAN · Credit report · Bank statement analysis', style: mutedText),
              ]),
            ),
            const Spacer(),
            const Text("This stands in for the lender's own page in the demo.", textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: C.faint)),
            const SizedBox(height: 12),
            Btn('Submit application', onPressed: f.lenderSubmitted),
          ]),
        ),
      ),
    );
  }
}

class LoansScreen extends StatelessWidget {
  const LoansScreen(this.f, {super.key});
  final IppoFlow f;

  @override
  Widget build(BuildContext context) {
    final a = f.offer;
    final o = a?['offer'] as Map<String, dynamic>?;
    return Scaffold(
      backgroundColor: C.soft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => f.go(Screen.chat)),
        title: const Text('My loans', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (f.applied && o != null)
          IppoCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(inr(o['amount'] as num), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
                const Pill('Under review', tone: PillTone.warn),
              ]),
              const SizedBox(height: 4),
              Text('${inr(o['emi'] as num?)} a month for ${o['tenure']} months', style: mutedText),
              const SizedBox(height: 4),
              Text('${a?['ref'] ?? ''}${a?['bank'] != null ? ' · ${a!['bank']}' : ''}', style: const TextStyle(fontSize: 11.5, color: C.faint)),
            ]),
          )
        else
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(child: Text('No loans yet.', style: TextStyle(color: C.muted))),
          ),
      ]),
    );
  }
}
