// Ippo, the voice loan assistant, on Flutter: a live call (ippo_agents) and the real PAN, credit and
// statement steps (ippo_loanpilot), with every API key kept on the backend.
import 'package:flutter/material.dart';

import 'flow.dart';
import 'screens.dart';
import 'ui.dart';

void main() => runApp(const IppoApp());

class IppoApp extends StatefulWidget {
  const IppoApp({super.key});

  @override
  State<IppoApp> createState() => _IppoAppState();
}

class _IppoAppState extends State<IppoApp> {
  final _flow = IppoFlow();

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ippo',
        debugShowCheckedModeBanner: false,
        theme: ippoTheme(),
        home: ListenableBuilder(
          listenable: _flow,
          builder: (_, __) => PopScope(
            // back from the lender's page or My loans returns to the chat, like the web demo
            canPop: _flow.screen == Screen.entry,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_flow.screen == Screen.lender) return _flow.lenderClosed();
              if (_flow.screen == Screen.loans) return _flow.go(Screen.chat);
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: switch (_flow.screen) {
                Screen.entry => EntryScreen(_flow, key: const ValueKey('entry')),
                Screen.chat => ChatScreen(_flow, key: const ValueKey('chat')),
                Screen.lender => LenderScreen(_flow, key: const ValueKey('lender')),
                Screen.loans => LoansScreen(_flow, key: const ValueKey('loans')),
              },
            ),
          ),
        ),
      );
}
