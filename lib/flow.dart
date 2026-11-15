// The demo's state and the call with Ippo: which screen is up, the chat so far, and what each of Ippo's
// client tools does. Mirrors ippo-voice-demo (web): Ippo drives the cards with show_step, and the real
// PAN, credit and statement steps run on LoanPilot through the backend.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ippo_agents/ippo_agents.dart';
import 'package:ippo_loanpilot/ippo_loanpilot.dart';
import 'package:permission_handler/permission_handler.dart';

import 'backend.dart';
import 'config.dart';

enum Screen { entry, chat, lender, loans }

enum LiveStatus { idle, connecting, on, error }

/// What the user said or did: words, a file, or a status note.
class UserBit {
  const UserBit.say(this.text, {this.mono = false})
      : kind = 'say',
        note = null,
        tone = null;
  const UserBit.file(this.text, this.note)
      : kind = 'file',
        mono = false,
        tone = null;
  const UserBit.note(this.text, {this.tone = 'plain'})
      : kind = 'note',
        mono = false,
        note = null;

  final String kind;
  final String text;
  final String? note;
  final bool mono;

  /// For notes: ok | bad | plain.
  final String? tone;
}

/// One turn in the chat: the user's words, Ippo's words, and/or a card Ippo showed.
class Turn {
  Turn({this.user, this.said, this.saying = false, this.step, this.amount, this.data}) : key = _seq++;
  static int _seq = 0;

  final int key;
  UserBit? user;
  String? said;

  /// Ippo is still saying this line: sentences arrive as they start being spoken.
  bool saying;
  String? step;
  int? amount;

  /// Real data behind the card (credit report, analysis), from LoanPilot.
  Map<String, dynamic>? data;
}

/// Cards Ippo can show with show_step (the agent's STEPS), plus the app's own real ones.
const askSteps = {'heard', 'pan', 'bankChoice', 'statement', 'applyNote', 'lenderBack', 'applied'};

/// Steps that carry on by themselves: a running check, or the note before the lender's page opens.
const goesOn = {'checkCredit', 'applyNote'};

String inr(num? n) {
  if (n == null) return 'unknown';
  final s = n.round().toString();
  if (s.length <= 3) return '₹$s';
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '₹${parts.join(',')},$last3';
}

class IppoFlow extends ChangeNotifier {
  Screen screen = Screen.entry;
  final turns = <Turn>[];
  LiveStatus status = LiveStatus.idle;
  String? error;
  bool botSpeaking = false;
  bool muted = false;

  /// Ippo has the user's turn and is working on a reply.
  bool thinking = false;

  /// The real offer from the analysis, once there is one (the lender and My loans screens use it).
  Map<String, dynamic>? offer;
  bool applied = false;

  /// The Account Aggregator consent, kept live while it is followed (the AA card shows it).
  Map<String, dynamic>? aaConsent;

  VoiceCall? _call;
  final _subs = <StreamSubscription<dynamic>>[];
  String? _customer;
  int? _amount;
  String? _lastSaid;

  bool get live => status == LiveStatus.on;

  /// The newest card is the one the user can still tap.
  int? get activeTurn {
    for (var i = turns.length - 1; i >= 0; i--) {
      if (turns[i].step != null) return turns[i].key;
    }
    return null;
  }

  void go(Screen s) {
    screen = s;
    notifyListeners();
  }

  // ---- the call ------------------------------------------------------------

  Future<void> start() async {
    await end();
    turns.clear();
    offer = null;
    applied = false;
    aaConsent = null;
    _customer = null;
    _amount = null;
    screen = Screen.chat;
    status = LiveStatus.connecting;
    error = null;
    notifyListeners();
    try {
      if (!(await Permission.microphone.request()).isGranted) {
        throw Exception('Ippo needs the microphone. Allow it in Settings and try again.');
      }
      Trace.log('calling Ippo', {'agent': agentId});
      final call = await agents.startVoiceCall(agentId: agentId);
      _call = call;
      Trace.log('in room', {'callId': call.callId});
      call
        ..onToolCall('show_step', _showStep)
        ..onToolCall('check_pan', _checkPan)
        ..onToolCall('start_aa', (_) => _startAa());
      _subs
        ..add(call.states.listen(_onState))
        ..add(call.botSpeaking.listen((on) {
          botSpeaking = on;
          if (on) thinking = false;
          Trace.log(on ? 'Ippo speaking' : 'Ippo stopped');
          notifyListeners();
        }))
        ..add(call.transcripts.listen(_onTranscript))
        ..add(call.rawEvents.listen((e) => Trace.log('data (first of its kind): ${e.type}')));
      status = LiveStatus.on;
      notifyListeners();
    } catch (e) {
      Trace.log('✗ call failed', '$e');
      await end();
      status = LiveStatus.error;
      error = '$e'.replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void _onState(CallState s) {
    Trace.log('call ${s.status.name}', s.error);
    if (s.status == CallStatus.ended || s.status == CallStatus.error) {
      // the bot hung up (idle timeout, error) or we did: the screen says "Call ended"
      _call = null;
      status = s.status == CallStatus.error ? LiveStatus.error : LiveStatus.idle;
      error = s.error;
      botSpeaking = false;
      thinking = false;
      notifyListeners();
    }
  }

  void _onTranscript(Transcript t) {
    if (t.role == TranscriptRole.user) {
      if (!t.isFinal) return;
      _lastSaid = t.text;
      Trace.log('user said', t.text);
      _addUser(UserBit.say(t.text));
      thinking = true;
    } else if (t.isFinal) {
      Trace.log('Ippo said', t.text);
      _said(t.text);
    } else {
      _saying(t.text);
    }
    notifyListeners();
  }

  /// A tap or a typed line, sent to Ippo as the user's words.
  void tap(UserBit user) {
    if (_call == null) return;
    _addUser(user);
    final words = user.kind == 'file' ? 'I added the file ${user.text}' : user.text;
    send('[tap] $words');
  }

  void send(String text) {
    final call = _call;
    if (call == null) return;
    _lastSaid = text;
    Trace.log('user tapped/typed', text);
    thinking = true;
    notifyListeners();
    call.sendUserMessage(text);
  }

  Future<void> setMuted(bool on) async {
    muted = on;
    notifyListeners();
    Trace.log(on ? 'mic muted' : 'mic unmuted');
    await _call?.setMicEnabled(!on);
  }

  Future<void> end() async {
    final call = _call;
    _call = null;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (call != null) {
      Trace.log('user ended the call');
      await call.end();
    }
    if (status == LiveStatus.on || status == LiveStatus.connecting) status = LiveStatus.idle;
    botSpeaking = false;
    thinking = false;
    notifyListeners();
  }

  void restart() {
    unawaited(end());
    turns.clear();
    screen = Screen.entry;
    status = LiveStatus.idle;
    error = null;
    notifyListeners();
  }

  // ---- the chat (same merging as the web demo's reducer) ---------------------

  void _addUser(UserBit u) {
    turns.add(Turn(user: u));
    screen = screen == Screen.entry ? Screen.chat : screen;
  }

  /// A sentence Ippo starts speaking now: add it to the line in progress, so text and voice land together.
  void _saying(String text) {
    final last = turns.isEmpty ? null : turns.last;
    if (last?.said != null && last!.said!.contains(text)) return;
    if (last != null && last.saying) {
      last.said = '${last.said ?? ''} $text'.trim();
    } else if (last != null && last.said == null && (last.user != null || last.step != null)) {
      last
        ..said = text
        ..saying = true;
    } else {
      turns.add(Turn(said: text, saying: true));
    }
  }

  /// The finished line: replaces the sentences shown while speaking.
  void _said(String text) {
    final last = turns.isEmpty ? null : turns.last;
    if (last != null && last.saying) {
      last
        ..said = text
        ..saying = false;
    } else if (last != null && last.said == null && (last.user != null || last.step != null)) {
      last.said = text;
    } else {
      turns.add(Turn(said: text));
    }
  }

  /// The card goes under what Ippo just said; otherwise it stands on its own.
  void _step(String step, {int? amount, Map<String, dynamic>? data}) {
    final last = turns.isEmpty ? null : turns.last;
    if (last != null && last.said != null && last.step == null) {
      last
        ..step = step
        ..amount = amount
        ..data = data;
    } else {
      turns.add(Turn(step: step, amount: amount, data: data));
    }
    screen = Screen.chat;
    notifyListeners();
  }

  // ---- Ippo's client tools ---------------------------------------------------

  Future<String> _showStep(Map<String, dynamic> args) async {
    final step = '${args['step'] ?? ''}';
    Trace.log('tool call', {'name': 'show_step', 'args': args});
    if (step == 'lender' || step == 'loans') {
      go(step == 'lender' ? Screen.lender : Screen.loans);
      return 'Opened $step';
    }
    if (!askSteps.contains(step)) {
      return 'Unknown step "$step". Use one of: ${askSteps.join(', ')}, lender, loans';
    }
    final amount = int.tryParse('${args['amount'] ?? ''}'.replaceAll(RegExp(r'[^\d]'), ''));
    if (amount != null && step == 'heard') {
      // safety net: the LLM once showed ₹1,00,000 for a typed "10000"; check against what they actually said
      final said = _lastSaid == null ? null : amountIn(_lastSaid!);
      if (said != null && said != amount) {
        Trace.log('✗ amount mismatch', {'said': said, 'shown': amount});
        return 'Wrong amount: the user said ${inr(said)} but you showed ${inr(amount)}. '
            'Call show_step("heard", amount $said) again and repeat it back to them.';
      }
      _amount = amount;
    }
    _step(step, amount: amount);
    // The bot runs the LLM again on this result, so the result says what to do next: after a check, go on to
    // its result; after a question card, wait, or Ippo answers its own question and skips ahead.
    final shown = 'Card "$step" is on the screen${amount != null ? ' (₹$amount)' : ''}.';
    return goesOn.contains(step)
        ? '$shown The check is done: now say its result and show the next card.'
        : "$shown Now wait for the user's answer. Do not speak again and do not call show_step until they reply.";
  }

  /// check_pan: the real PAN + credit check on LoanPilot (customer, then Experian, Equifax if Experian fails).
  Future<String> _checkPan(Map<String, dynamic> args) async {
    final pan = '${args['pan'] ?? ''}'.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    Trace.log('tool call', {'name': 'check_pan', 'pan': pan.length >= 5 ? '${pan.substring(0, 5)}•••••' : pan});
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      return '"$pan" is not a valid PAN (5 letters, 4 digits, 1 letter). Ask them to type it again in the PAN card.';
    }
    _step('checkCredit');
    const next = 'Then ask how they want to share 6 months of bank statements, and call show_step("bankChoice").';
    try {
      // the backend replaces name and mobile with the applicant's own
      final customer = await loanpilot.customers.create(pan: pan, name: '-', mobile: '-');
      _customer = customer.id;
      CreditCheck? check;
      var bureau = 'experian';
      String? creditError;
      for (final b in const ['experian', 'equifax']) {
        try {
          // bureau and pan are accepted by the API; the SDK's create() doesn't take them yet
          final j = await loanpilot.requestJson('POST', '/credit-checks',
              body: {'name': '-', 'mobile': '-', 'consent': true, 'bureau': b, 'pan': pan});
          check = CreditCheck.fromJson((j as Map).cast<String, dynamic>());
          bureau = b;
          break;
        } on LoanPilotException catch (e) {
          creditError = e.message;
          Trace.log('$b failed', e.message);
        }
      }
      final k = {...?check?.raw, ...?check?.bureau};
      final data = <String, dynamic>{
        'customer': {'id': customer.id, 'ref': customer.ref, 'name': customer.name},
        'credit': check == null
            ? null
            : {
                'bureau': bureau,
                'score': check.score,
                'activeLoans': k['active_loans'],
                'outstanding': k['total_outstanding'],
                'overdue': k['total_overdue'] ?? k['overdue_amount'],
                'writtenOff': k['written_off_accounts'] ?? k['written_off'],
                'reused': check.raw['reused'] == true,
              },
        'creditError': check == null ? creditError : null,
      };
      Trace.log('PAN check result', {'customer': customer.ref, 'score': check?.score, 'bureau': bureau});
      _step('credit', data: data);
      final c = data['credit'] as Map<String, dynamic>?;
      return c != null
          ? 'PAN verified for ${customer.name} (${customer.ref}). ${bureau == 'equifax' ? 'Equifax' : 'Experian'} credit score '
              '${c['score'] ?? 'not available'}, ${c['activeLoans'] ?? 0} active loans, ${inr(c['outstanding'] as num?)} outstanding, '
              '${inr(c['overdue'] as num?)} overdue. The credit card is on screen. In one or two short sentences tell them their score '
              'and what it means. $next'
          : 'PAN verified for ${customer.name} (${customer.ref}), but the credit report could not be pulled: $creditError. '
              'Say so in one sentence. $next';
    } on LoanPilotException catch (e) {
      _step('credit', data: {'error': e.message});
      return 'The PAN check failed on LoanPilot: ${e.message}. Tell them plainly in one sentence and offer to try again.';
    }
  }

  /// start_aa: a real Account Aggregator consent (SDK `lp.aa`). The backend sets the applicant's mobile; the
  /// SMS link is also on the card. [_followAa] follows it to the analysis.
  Future<String> _startAa() async {
    Trace.log('tool call', {'name': 'start_aa'});
    try {
      final c = await loanpilot.aa.start(mobile: '-', fiMonths: 6, customer: _customer);
      aaConsent = c.raw;
      _step('aa', data: {'consent': c.raw});
      unawaited(_followAa(c.id));
      return 'A real ${c.provider == 'finpass' ? 'Finpass' : 'SAAFE'} consent link was sent by SMS to the number ending '
          '${(c.mobile ?? '').length >= 4 ? c.mobile!.substring(c.mobile!.length - 4) : '?'}. The card shows it with a live status. '
          'Tell them to open the SMS link (or tap Open link on the card), pick their bank and approve. '
          'Then wait: a "[system]" message brings the result.';
    } on LoanPilotException catch (e) {
      _step('aa', data: {'error': e.message});
      return 'Sending the Account Aggregator link failed: ${e.message}. Say so in one sentence and offer the PDF upload '
          'instead (show_step("statement")).';
    }
  }

  /// Follow a consent until the statement is fetched and analysed, keeping the card's status live.
  Future<void> _followAa(String id) async {
    final t0 = DateTime.now();
    var last = aaConsent?['status'] as String?;
    var analysing = false;
    for (var n = 1;; n++) {
      await Future<void>.delayed(const Duration(seconds: 6));
      if (aaConsent?['id'] != id) return; // a new call started
      AaConsent c;
      try {
        // a forced refresh only every 5th check (it is rate-limited; the server's own poll advances it too)
        c = n % 5 == 0 ? await loanpilot.aa.refresh(id).catchError((Object _) => loanpilot.aa.get(id)) : await loanpilot.aa.get(id);
      } on LoanPilotException {
        continue;
      }
      aaConsent = c.raw;
      notifyListeners();
      if (c.status != last) Trace.log('AA status ${c.status}', c.raw['error']);
      // only "fetching" is worth saying; a bare "completed" made Ippo invent an offer, so the analysis result follows
      if (c.status != last && c.status == 'fetching') {
        send('[system] Account Aggregator: they approved and the bank is sending the statement. Say so briefly. There is no result yet.');
      }
      last = c.status;
      if (c.isReady && !analysing) {
        analysing = true;
        try {
          aaConsent = (await loanpilot.aa.analyse(id, c.statements)).raw;
        } on LoanPilotException catch (e) {
          Trace.log('AA analyse failed', e.message);
        }
      }
      if ((c.isCompleted || analysing) && c.analyses.isNotEmpty) {
        final a = await loanpilot.analyses.get('${c.analyses.first['id']}');
        if (_customer != null) {
          try {
            await loanpilot.customers.attach(_customer!, kind: 'analysis', refOrId: a.id);
          } on LoanPilotException catch (e) {
            Trace.log('attach to customer failed', e.message);
          }
        }
        return _followAnalysis(a, (_) {});
      }
      if (const {'failed', 'rejected', 'cancelled'}.contains(c.status)) {
        return send('[system] The Account Aggregator request ${c.status}: ${c.raw['error'] ?? 'no reason given'}. '
            'Tell them plainly and offer the PDF upload (show_step("statement")).');
      }
      if (DateTime.now().difference(t0) > const Duration(minutes: 15)) {
        return send('[system] The Account Aggregator approval is still pending after 15 minutes.');
      }
    }
  }

  // ---- the statement ---------------------------------------------------------

  /// A statement PDF from the card: upload it to LoanPilot, follow the analysis, and tell Ippo the real result.
  Future<void> uploadStatement(List<int> bytes, String name, String? password, void Function(String) onStatus) async {
    _addUser(UserBit.file(name, 'Uploaded · ${(bytes.length / 1024).round().clamp(1, 1 << 30)} KB'));
    notifyListeners();
    send("[tap] I uploaded my bank statement $name. Say you are analysing it; the result comes in a moment.");
    onStatus('Uploading…');
    Analysis a;
    try {
      a = await loanpilot.analyses.create(CreateAnalysis(
        fileBytes: bytes,
        fileName: name,
        password: password,
        inputs: _amount == null ? null : {'requested_amount': _amount!},
      ));
    } on LoanPilotException catch (e) {
      onStatus('Upload failed: ${e.message}');
      return send('[system] LoanPilot could not take the statement: ${e.message}. Tell them plainly and ask them to try another PDF.');
    }
    Trace.log('statement analysis started', {'id': a.id, 'ref': a.ref});
    if (_customer != null) {
      try {
        await loanpilot.customers.attach(_customer!, kind: 'analysis', refOrId: a.id);
      } on LoanPilotException catch (e) {
        Trace.log('attach to customer failed', e.message);
      }
    }
    await _followAnalysis(a, onStatus);
  }

  Future<void> _followAnalysis(Analysis a, void Function(String) onStatus) async {
    final t0 = DateTime.now();
    while (true) {
      onStatus('Analysing ${a.ref ?? ''}… ${DateTime.now().difference(t0).inSeconds} s');
      await Future<void>.delayed(const Duration(seconds: 3));
      Analysis now;
      try {
        now = await loanpilot.analyses.get(a.id, includeResult: true);
      } on LoanPilotException {
        continue;
      }
      if (now.isCompleted) {
        onStatus('Analysed');
        final s = summarise(now);
        offer = s;
        _step('realOffer', data: s);
        final o = s['offer'] as Map<String, dynamic>?;
        final ok = o != null && (o['amount'] as num) > 0;
        return send('[system] LoanPilot analysed the statement (${s['ref']}${s['bank'] != null ? ', ${s['bank']}' : ''}'
            '${s['from'] != null ? ', ${s['from']} to ${s['to']}' : ''}). Decision: ${s['decision'] ?? 'none'}. '
            '${ok ? 'Offer: ${inr(o['amount'] as num)} at ${inr(o['emi'] as num?)} a month for ${o['tenure']} months, '
                '${(((o['rate'] as num?) ?? 0) * 1000).round() / 10}% a year${o['needsReview'] == true ? ", subject to an officer's review" : ''}.' : 'No loan can be offered now${o?['reason'] != null ? ': ${o!['reason']}' : ''}.'}'
            ' The offer card is on screen. Tell them the result in two short sentences and ask if they want to apply.');
      }
      if (now.isFailed) {
        onStatus('Analysis failed: ${now.error ?? 'unknown'}');
        return send('[system] LoanPilot could not analyse the statement: ${now.error ?? 'unknown error'}. Tell them plainly and ask for another PDF.');
      }
      if (DateTime.now().difference(t0) > const Duration(minutes: 6)) {
        onStatus('Still analysing — taking long');
        return send('[system] The analysis is taking longer than usual. Tell them it is still running.');
      }
    }
  }

  // ---- the lender's page -----------------------------------------------------

  void lenderSubmitted() {
    applied = true;
    screen = Screen.chat;
    tap(const UserBit.note("I submitted the application on the lender's page", tone: 'ok'));
  }

  void lenderClosed() {
    screen = Screen.chat;
    tap(const UserBit.note("I closed the lender's page before finishing"));
  }

  @override
  void dispose() {
    unawaited(end());
    super.dispose();
  }
}

/// The pieces of a finished analysis the app shows and Ippo says.
Map<String, dynamic> summarise(Analysis a) {
  final r = a.result ?? const {};
  final dec = (r['decision'] as Map?)?.cast<String, dynamic>() ?? const {};
  final o = (dec['loan_offer'] as Map?)?.cast<String, dynamic>() ?? const {};
  final acct = (r['account'] as Map?)?.cast<String, dynamic>() ?? const {};
  return {
    'id': a.id,
    'ref': a.ref,
    'status': a.status,
    'bank': a.bankName ?? acct['bank_name'],
    'decision': a.decision ?? dec['decision'],
    'score': a.finalScore ?? dec['final_score'],
    'from': acct['period_from'],
    'to': acct['period_to'],
    'offer': o['amount'] is num
        ? {
            'amount': o['amount'],
            'emi': o['emi'],
            'rate': o['rate'],
            'tenure': o['tenure_months'],
            'needsReview': o['needs_review'],
            'reason': o['reason'],
          }
        : null,
  };
}

/// The amount in the user's last words, in rupees ("10000", "2,00,000", "2 lakh", "1.5 lakh"), if any.
int? amountIn(String text) {
  final t = text.toLowerCase().replaceAll(',', '');
  final lakh = RegExp(r'(\d+(?:\.\d+)?)\s*(lakh|lac|லட்சம்|லேக்|लाख)').firstMatch(t);
  if (lakh != null) return (double.parse(lakh.group(1)!) * 100000).round();
  final n = RegExp(r'\b\d{4,8}\b').firstMatch(t);
  return n == null ? null : int.parse(n.group(0)!);
}
