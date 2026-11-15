# Ippo voice loan demo · Flutter

Ippo, IppoPay's voice loan assistant, as an Android app (iOS isn't set up yet). A live voice call with the Ippo agent; Ippo puts cards on the screen as it talks; the PAN, credit report and bank statement offer are real (LoanPilot, production).

Built only on the published SDKs:

| SDK | Used for |
|---|---|
| [`ippo_agents`](https://pub.dev/packages/ippo_agents) | The voice call, transcripts, Ippo's client tools (`show_step`, `check_pan`, `start_aa`), taps sent as words |
| [`ippo_loanpilot`](https://pub.dev/packages/ippo_loanpilot) | Customer (PAN), credit check, bank statement by Account Aggregator (`lp.aa`, 0.3.0+) or PDF upload, analysis |

## No keys in the app

The app holds no API key. Both SDKs talk through a backend, the way production apps do:

```
Phone (this app)                        Backend (ippo-voice-demo server, holds the keys)
IppoAgents.tokenProvider        →       POST /live/connect   → agent.ippo.one  (ippo_ key)
LoanPilot(baseUrl: backend)     →       /v1/* proxy          → app.ippo.one    (lp_live_ key)
```

The `/v1` proxy only allows the calls this app needs, and it sets the applicant (name, mobile) itself, so the app can't pull anyone else's credit report.

Not in this app yet: **text chat mode**. `startChat` needs an API key in the app, so voice is the only mode.

## Run it

1. Start the backend: the [ippo-voice-demo](https://github.com/ippo-one/ippo-voice-demo) repo with its `.env.local`, then `pnpm dev` (port 5180).
2. Start an Android emulator (or plug in a phone with USB debugging), and forward the port:
   ```bash
   adb reverse tcp:5180 tcp:5180
   ```
3. Run the app:
   ```bash
   flutter pub get
   flutter run
   ```

Options (`--dart-define`):

| Name | Default | What |
|---|---|---|
| `BACKEND_URL` | `http://localhost:5180` | The backend |
| `IPPO_AGENT_ID` | `1k0oQZbebOGychlKO1imI` | The Ippo agent on agent.ippo.one |

Every call event is logged by the backend in `logs/live.log`, tagged `[app]`, next to its `[sdk]` and `[lp-proxy]` requests.

## Real data

This is production: the PAN check pulls a real credit report (billable, reused for about 30 days) for the backend's `TEST_NAME` / `TEST_MOBILE`, Account Aggregator sends a real SMS to `TEST_MOBILE`, and the statement is really analysed.
