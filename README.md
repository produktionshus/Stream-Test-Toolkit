# Stream-Test-Toolkit

Test tools for live-streaming delivery (WE ARE ON). PowerShell 5.1 and a single HTML page, no dependencies.

| Folder | Tool | Purpose |
|---|---|---|
| `hosttest/` | `hosttest.ps1` | Can a web host serve N viewers behind one NAT IP? Simulates page loads + presence heartbeats from a single machine and reports 429/5xx/timeouts per endpoint |
| `stun-test/` | `stun-test.html` | Browser-side diagnosis of the WebRTC path to Ant Media: STUN, TCP 5443 websocket, real ICE against an edge, selected candidate pairs |
| `stun-test/` | `stun-ping.ps1` | STUN Binding Request (UDP) from the command line; shows whether UDP to STUN/TURN leaves the customer's network |

## hosttest

```powershell
.\hosttest\hosttest.ps1 https://candidate-host -Viewers 1000 -Seconds 180 -Heartbeat 30
```

Exit 0 = every response was 200/204. Exit 1 = the host rejected or dropped requests from a single IP at this load. Run it from a line that is not itself behind the customer's NAT, and never against a host while an event is on air.

Parameters: `-Viewers` (500), `-Seconds` (120), `-Heartbeat` seconds between presence POSTs per viewer (30; the portal uses 120), `-Ramp` seconds over which all viewers start (20), `-Event` slug (jndata).

Endpoints: `/?e=<event>`, `/data/config.json`, `/js/app.js`, `/css/styles.css` once per viewer, then `POST /admin/presence.php` per heartbeat. Failures are reported with the second they occurred in.

Background: on 21 October 2026 a shared web host rate-limited ~500 viewers behind one corporate NAT (429, 503, dropped connections). This test reproduces that pattern in 25 seconds and is the acceptance test for any portal host (passed on Azure Static Web Apps with 3000 viewers from one IP).

## stun-test

Open `stun-test.html` in a browser on the customer's network (also hosted at weareon.net/stun-test.html). It tests step by step: Google STUN (UDP 19302), websocket to the edge pool (TCP 5443), ICE against an edge (UDP 5000–65000), and lists the candidate pairs that were selected. The result tells whether a problem is UDP (firewall/SSE steering) or signalling.

```powershell
.\stun-test\stun-ping.ps1                      # Google STUN
.\stun-test\stun-ping.ps1 turn.weareon.net 5555
```

Søren Østergaard · Luminance/Dypång Management · weareon.net
