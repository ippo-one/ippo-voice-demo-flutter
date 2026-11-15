/// Where the app finds its backend and which agent it calls. Neither is a secret: the API keys live only on
/// the backend (the ippo-voice-demo dev server). Override at build time, e.g.
/// `flutter run --dart-define=BACKEND_URL=http://localhost:5180`.
library;

/// The ippo-voice-demo server. On an emulator or a USB phone, `adb reverse tcp:5180 tcp:5180` makes the
/// computer's localhost:5180 reachable as the phone's localhost:5180.
const backendUrl = String.fromEnvironment('BACKEND_URL', defaultValue: 'http://localhost:5180');

/// The Ippo agent on agent.ippo.one (created by `pnpm agent:setup` in ippo-voice-demo).
const agentId = String.fromEnvironment('IPPO_AGENT_ID', defaultValue: '1k0oQZbebOGychlKO1imI');
