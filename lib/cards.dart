// The cards Ippo puts in the chat (show_step), and the real ones behind check_pan and the statement upload.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'flow.dart';
import 'ui.dart';

/// The card for [turn]. Only the newest card ([active]) can still be tapped.
Widget stepCard(IppoFlow f, Turn turn, {required bool active}) {
  final on = active && f.live;
  return switch (turn.step) {
    'heard' => _Heard(f, turn.amount, on),
    'pan' => _PanInput(f, on),
    'checkCredit' => const _Checking('Checking your PAN and credit report…'),
    'credit' => _Credit(turn.data),
    'bankChoice' => _BankChoice(f, on),
    'statement' => _Statement(f, on),
    'aa' => _Aa(f, turn.data),
    'realOffer' => _Offer(f, turn.data, on),
    'applyNote' => const _Note(Icons.open_in_new, "Opening the lender's page", 'You finish the application on their page, then come back here.'),
    'lenderBack' => _LenderBack(f, on),
    'applied' => _Applied(f),
    _ => const SizedBox.shrink(),
  };
}

class _Heard extends StatelessWidget {
  const _Heard(this.f, this.amount, this.on);
  final IppoFlow f;
  final int? amount;
  final bool on;

  @override
  Widget build(BuildContext context) => IppoCard(
        child: Column(children: [
          Row(children: [
            const Expanded(child: Text('Loan amount heard', style: TextStyle(fontSize: 13, color: C.muted))),
            Text(inr(amount ?? 0), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.5)),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Btn("Yes, that's right", onPressed: on ? () => f.tap(const UserBit.say("Yes, that's right")) : null)),
            const SizedBox(width: 8),
            Expanded(child: Btn('Say it again', tone: BtnTone.ghost, onPressed: on ? () => f.tap(const UserBit.say("No, I'll say it again")) : null)),
          ]),
        ]),
      );
}

class _PanInput extends StatefulWidget {
  const _PanInput(this.f, this.on);
  final IppoFlow f;
  final bool on;

  @override
  State<_PanInput> createState() => _PanInputState();
}

class _PanInputState extends State<_PanInput> {
  final _c = TextEditingController();
  bool get _ok => RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(_c.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IppoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('PAN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.muted))),
            Text('${_c.text.length} of 10', style: const TextStyle(fontSize: 12, color: C.muted)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: _c,
            enabled: widget.on,
            autofocus: widget.on,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(10),
              TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
            ],
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: 3),
            decoration: const InputDecoration(hintText: 'ABCDE1234F'),
          ),
          const SizedBox(height: 8),
          const Text('Type it exactly as on your PAN card: 5 letters, 4 numbers, 1 letter.', style: TextStyle(fontSize: 11.5, color: C.muted)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Btn('Verify PAN', onPressed: widget.on && _ok ? () => widget.f.tap(UserBit.say(_c.text, mono: true)) : null),
          ),
        ]),
      );
}

class _Checking extends StatelessWidget {
  const _Checking(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => IppoCard(
        child: Row(children: [
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: C.ippo500)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: C.ink2))),
        ]),
      );
}

class _Credit extends StatelessWidget {
  const _Credit(this.data);
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null) return const SizedBox.shrink();
    if (d['error'] != null) {
      return IppoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardHead('PAN check failed'),
          Text('${d['error']}', style: const TextStyle(fontSize: 12.5, color: C.bad)),
        ]),
      );
    }
    final c = d['credit'] as Map<String, dynamic>?;
    final cust = d['customer'] as Map<String, dynamic>? ?? const {};
    final score = c?['score'] as int?;
    final tone = score == null
        ? C.muted
        : score >= 750
            ? C.ok
            : score >= 650
                ? C.warn
                : C.bad;
    return IppoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardHead('PAN verified'),
        Text('${cust['name'] ?? ''} · ${cust['ref'] ?? ''}', style: const TextStyle(fontSize: 13, color: C.muted)),
        const SizedBox(height: 12),
        if (c != null)
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Column(children: [
              Text(score?.toString() ?? '–', style: TextStyle(fontSize: 40, height: 1, fontWeight: FontWeight.w700, color: tone)),
              const SizedBox(height: 4),
              Text('${c['bureau'] == 'equifax' ? 'Equifax' : 'Experian'} score', style: const TextStyle(fontSize: 11, color: C.muted)),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.1,
                children: [
                  _kv('Active loans', '${c['activeLoans'] ?? 0}'),
                  _kv('Outstanding', inr((c['outstanding'] as num?) ?? 0)),
                  _kv('Overdue', inr((c['overdue'] as num?) ?? 0)),
                  _kv('Written off', '${c['writtenOff'] ?? 0}'),
                ],
              ),
            ),
          ])
        else
          Text('Credit report not available: ${d['creditError']}', style: const TextStyle(fontSize: 12.5, color: C.warn)),
        if (c?['reused'] == true)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Re-used a recent report (no new bureau charge).', style: TextStyle(fontSize: 11, color: C.faint)),
          ),
      ]),
    );
  }

  Widget _kv(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(k, style: const TextStyle(fontSize: 11, color: C.muted)),
          Text(v, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
        ]),
      );
}

class _BankChoice extends StatelessWidget {
  const _BankChoice(this.f, this.on);
  final IppoFlow f;
  final bool on;

  @override
  Widget build(BuildContext context) => IppoCard(
        padding: const EdgeInsets.all(6),
        child: Column(children: [
          _row(Icons.upload_file, 'Upload bank statement', 'From your bank’s app or website', const Pill('PDF, last 6 months', tone: PillTone.ippo),
              on ? () => f.tap(const UserBit.say('Upload')) : null),
          const Divider(height: 1, indent: 12, endIndent: 12, color: C.line),
          _row(Icons.account_balance, 'Account Aggregator', 'Pick your bank and approve with an OTP', const Pill('No file needed', tone: PillTone.ok),
              on ? () => f.tap(const UserBit.say('Account aggregator')) : null),
        ]),
      );

  Widget _row(IconData icon, String title, String sub, Widget tag, VoidCallback? onTap) => ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: C.ippo50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: C.ippo600, size: 20),
          ),
          title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sub, style: const TextStyle(fontSize: 12, color: C.muted)),
              const SizedBox(height: 6),
              tag,
            ]),
          ),
          trailing: const Icon(Icons.chevron_right, color: C.faint),
      );
}

class _Statement extends StatefulWidget {
  const _Statement(this.f, this.on);
  final IppoFlow f;
  final bool on;

  @override
  State<_Statement> createState() => _StatementState();
}

class _StatementState extends State<_Statement> {
  final _pw = TextEditingController();
  String? _status;
  bool get _busy => _status != null && !RegExp('failed|Analysed').hasMatch(_status!);

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['pdf']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await widget.f.uploadStatement(bytes, file.name, _pw.text.isEmpty ? null : _pw.text, (s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  Widget build(BuildContext context) => IppoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardHead('Upload bank statement'),
          const Text('Last 6 months, PDF from your bank’s app or website. LoanPilot reads it and works out what you can borrow.', style: mutedText),
          const SizedBox(height: 12),
          TextField(
            controller: _pw,
            enabled: widget.on && !_busy,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'PDF password (if any)'),
          ),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: Btn('Choose PDF', icon: Icons.upload, onPressed: widget.on && !_busy ? _pick : null)),
          if (_status != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (_busy) ...[const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.ippo500)), const SizedBox(width: 8)],
              Expanded(child: Text(_status!, style: TextStyle(fontSize: 12.5, color: _status!.contains('failed') ? C.bad : C.ink2))),
            ]),
          ],
        ]),
      );
}

const _aaSteps = [
  ('pending', 'Link sent by SMS · waiting for your approval'),
  ('approved', 'Approved'),
  ('fetching', 'Your bank is sending the statement'),
  ('completed', 'Statement received and analysed'),
];

/// The live Account Aggregator consent: its status, and the approval link right here in the chat too.
class _Aa extends StatelessWidget {
  const _Aa(this.f, this.data);
  final IppoFlow f;
  final Map<String, dynamic>? data;

  @override
  Widget build(BuildContext context) {
    if (data?['error'] != null) {
      return IppoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardHead('Account Aggregator'),
          Text('${data!['error']}', style: const TextStyle(fontSize: 12.5, color: C.bad)),
        ]),
      );
    }
    final c = f.aaConsent ?? (data?['consent'] as Map<String, dynamic>?);
    if (c == null) return const SizedBox.shrink();
    final status = '${c['status']}';
    // "ready": the bank sent it and LoanPilot is analysing, the same point as "fetching" on the card
    final at = status == 'ready' ? 2 : _aaSteps.indexWhere((s) => s.$1 == status).clamp(0, 3);
    final bad = const {'failed', 'rejected', 'cancelled'}.contains(status);
    final url = c['approval_url'] as String?;
    final mobile = '${c['mobile'] ?? ''}';
    return IppoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CardHead('AA · ${c['provider'] == 'finpass' ? 'Finpass' : 'SAAFE'}'),
        Text('Sent to ${mobile.length >= 4 ? '••••••${mobile.substring(mobile.length - 4)}' : 'your mobile'}. Open the SMS link, pick your bank and approve.',
            style: mutedText),
        const SizedBox(height: 10),
        if (bad)
          Text('$status: ${c['error'] ?? 'no reason given'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.bad))
        else
          for (var i = 0; i < _aaSteps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                _tick(i < at || status == 'completed' ? 'done' : (i == at ? 'doing' : 'todo')),
                const SizedBox(width: 10),
                Expanded(child: Text(_aaSteps[i].$2, style: TextStyle(fontSize: 13, color: i > at ? C.faint : C.ink2))),
              ]),
            ),
        if (url != null && !bad && status != 'completed')
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your consent link', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: C.muted)),
              const SizedBox(height: 2),
              Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: C.ink2)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Btn('Open link', small: true, onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication))),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn('Copy link', small: true, tone: BtnTone.ghost, onPressed: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Link copied')));
                  }),
                ),
              ]),
            ]),
          ),
      ]),
    );
  }

  Widget _tick(String state) => switch (state) {
        'done' => const CircleAvatar(radius: 9, backgroundColor: C.ok, child: Icon(Icons.check, size: 12, color: Colors.white)),
        'doing' => const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: C.ippo500)),
        _ => Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.line, width: 2))),
      };
}

class _Offer extends StatelessWidget {
  const _Offer(this.f, this.data, this.on);
  final IppoFlow f;
  final Map<String, dynamic>? data;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final a = data;
    if (a == null) return const SizedBox.shrink();
    final o = a['offer'] as Map<String, dynamic>?;
    final ok = o != null && (o['amount'] as num) > 0;
    final decision = a['decision'] as String?;
    final rate = (((o?['rate'] as num?) ?? 0) * 1000).round() / 10;
    return IppoCard(
      accent: ok,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const CardHead('Your LoanPilot offer'),
        Text([a['ref'], a['bank'], if (a['from'] != null) '${a['from']} – ${a['to']}'].whereType<Object>().join(' · '),
            style: const TextStyle(fontSize: 12, color: C.muted)),
        if (ok) ...[
          const SizedBox(height: 8),
          Text(inr(o['amount'] as num), style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -.6)),
          Text.rich(TextSpan(style: const TextStyle(fontSize: 13, color: C.muted), children: [
            TextSpan(text: inr(o['emi'] as num?), style: const TextStyle(fontWeight: FontWeight.w700, color: C.ink2)),
            TextSpan(text: ' a month for ${o['tenure']} months · $rate% a year'),
          ])),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (decision != null)
              Pill(decision,
                  tone: RegExp('approv', caseSensitive: false).hasMatch(decision)
                      ? PillTone.ok
                      : RegExp('declin|reject', caseSensitive: false).hasMatch(decision)
                          ? PillTone.bad
                          : PillTone.warn),
            if (o['needsReview'] == true && !RegExp('review', caseSensitive: false).hasMatch(decision ?? '')) const Pill('Officer review', tone: PillTone.warn),
            if (a['score'] != null) Pill('Score ${a['score']}'),
          ]),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: Btn('Apply', onPressed: on ? () => f.tap(const UserBit.say('I want to apply for this loan')) : null)),
        ] else
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No loan can be offered now${o?['reason'] != null ? ': ${o!['reason']}' : '.'}', style: const TextStyle(fontSize: 13, color: C.bad)),
          ),
      ]),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.icon, this.title, this.sub);
  final IconData icon;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) => IppoCard(
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: C.ippo50, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 18, color: C.ippo600),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(sub, style: mutedText),
            ]),
          ),
        ]),
      );
}

class _LenderBack extends StatelessWidget {
  const _LenderBack(this.f, this.on);
  final IppoFlow f;
  final bool on;

  @override
  Widget build(BuildContext context) => IppoCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CardHead('Application not finished', live: false),
          const Text("You closed the lender's page before submitting. Your offer is still there.", style: mutedText),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: Btn("Open the lender's page again", onPressed: on ? () => f.go(Screen.lender) : null)),
        ]),
      );
}

class _Applied extends StatelessWidget {
  const _Applied(this.f);
  final IppoFlow f;

  @override
  Widget build(BuildContext context) {
    final o = f.offer?['offer'] as Map<String, dynamic>?;
    return IppoCard(
      accent: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const CircleAvatar(radius: 14, backgroundColor: C.ok, child: Icon(Icons.check, size: 16, color: Colors.white)),
          const SizedBox(width: 10),
          const Expanded(child: Text('Application sent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
          if (o != null) Text(inr(o['amount'] as num), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        const Text('The lender is reviewing it. You’ll get an SMS when there’s an update.', style: mutedText),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: Btn('See My loans', tone: BtnTone.ghost, onPressed: () => f.go(Screen.loans))),
      ]),
    );
  }
}
