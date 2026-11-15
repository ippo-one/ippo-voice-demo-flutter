// The app's two SDK clients. Both talk to agent.ippo.one / app.ippo.one through the backend, so no API key
// ships in the APK (an APK can be unpacked; a key in it is a key anyone has).
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ippo_agents/ippo_agents.dart';
import 'package:ippo_loanpilot/ippo_loanpilot.dart';

import 'config.dart';

/// Voice calls (ippo_agents, production mode): the backend calls `POST /api/agents/{id}/connect` with the
/// ippo_ key and hands back a room token good for this one call.
final agents = IppoAgents.tokenProvider((agentId, options) async {
  final r = await http.post(
    Uri.parse('$backendUrl/live/connect'),
    headers: {'content-type': 'application/json'},
    body: '{}',
  );
  final j = (jsonDecode(r.body) as Map).cast<String, dynamic>();
  if (r.statusCode != 200) throw Exception(j['error'] ?? 'Could not reach Ippo (${r.statusCode})');
  return ConnectResult.fromJson(j);
});

/// LoanPilot (ippo_loanpilot), pointed at the backend's /v1 proxy: it adds the lp_live_ key, allows only the
/// calls this app needs, and sets the applicant (name, mobile) itself. The SDK wants a token; a real app
/// would pass the borrower's session token here.
final loanpilot = LoanPilot(apiKey: 'app-session', baseUrl: backendUrl);

/// Call events go to the backend's log (logs/live.log, tagged [app]), next to its SDK requests, so one file
/// shows the whole call.
class Trace {
  static final _queue = <Map<String, dynamic>>[];
  static Timer? _flush;

  static void log(String what, [Object? data]) {
    _queue.add({'what': what, if (data != null) 'data': data, 't': DateTime.now().millisecondsSinceEpoch});
    _flush ??= Timer(const Duration(milliseconds: 300), () {
      final events = List.of(_queue);
      _queue.clear();
      _flush = null;
      unawaited(http
          .post(Uri.parse('$backendUrl/live/log'),
              headers: {'content-type': 'application/json'}, body: jsonEncode({'source': 'app', 'events': events}))
          .catchError((_) => http.Response('', 0)));
    });
  }
}
