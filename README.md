# Stream-Test-Toolkit

Testværktøjer til streaming-leverancer (WE ARE ON). PowerShell 5.1 og én HTML-side, ingen afhængigheder.

| Mappe | Værktøj | Formål |
|---|---|---|
| `hosttest/` | `hosttest.ps1` | Kan en webhost holde til N seere bag én NAT-IP? Simulerer sideindlæsning + heartbeat fra én maskine og rapporterer 429/5xx/timeouts pr. endpoint |
| `stun-test/` | `stun-test.html` | Browser-side diagnose af WebRTC-vejen til Ant Media: STUN, TCP 5443 websocket, ægte ICE mod en edge, kandidatpar |
| `stun-test/` | `stun-ping.ps1` | STUN Binding Request (UDP) fra kommandolinjen; viser, om UDP til STUN/TURN kommer ud af kundens net |

## hosttest

```powershell
.\hosttest\hosttest.ps1 https://kandidat-host -Viewers 1000 -Seconds 180 -Heartbeat 30
```

Exit 0 = alle svar 200/204. Exit 1 = hosten afviser eller dropper requests fra én IP ved denne last. Kør fra en linje, der ikke selv er bag kundens NAT, og aldrig mod en host, mens et event sender.

Parametre: `-Viewers` (500), `-Seconds` (120), `-Heartbeat` sekunder mellem heartbeat-POST pr. seer (30; portalen bruger 120), `-Ramp` sekunder til at starte alle seere (20), `-Event` slug (jndata).

Endpoints: `/?e=<event>`, `/data/config.json`, `/js/app.js`, `/css/styles.css` én gang pr. seer, derefter `POST /admin/presence.php` pr. heartbeat. Fejl rapporteres med det sekund, de faldt i.

## stun-test

`stun-test.html` åbnes i browseren på kundens net (også hostet på weareon.net/stun-test.html). Den tester trinvis: Google STUN (UDP 19302), websocket til edge-poolen (TCP 5443), ICE mod en edge (UDP 5000–65000) og viser de kandidatpar, der blev valgt. Resultatet afgør, om et problem er UDP (firewall/SSE-steering) eller signalering.

```powershell
.\stun-test\stun-ping.ps1                      # Google STUN
.\stun-test\stun-ping.ps1 turn.weareon.net 5555
```

Søren Østergaard · Luminance/Dypång Management · weareon.net
