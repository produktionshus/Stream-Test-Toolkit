# WE ARE ON - host test: can a web host serve N viewers behind ONE IP (NAT) the way the portal loads it?
# Reproduces the event day of 21 Oct 2026 (a shared host returned 429 / empty responses at ~500 viewers behind the customer's NAT).
# Each simulated viewer: one page load (index, config.json, app.js, css), then presence heartbeat POSTs to admin/presence.php.
# Everything from this machine's IP. Do NOT run against a host while an event is on air (it only hits your own IP, but still).
#   .\hosttest.ps1 https://new-host.example                 500 viewers, 120 s, heartbeat 30 s
#   .\hosttest.ps1 https://weareon.net -Viewers 20 -Seconds 25 -Heartbeat 5
# Exit 0 = all responses 200/204. Exit 1 = 429 / 5xx / empty response / timeout.
param(
  [Parameter(Mandatory = $true)][string]$Base,
  [int]$Viewers = 500, [int]$Seconds = 120, [double]$Heartbeat = 30, [double]$Ramp = 20, [string]$Event = 'jndata'
)
$Base = ($Base -replace '[?#].*$', '').TrimEnd('/')   # origin + optional path only; pass ?e=slug via -Event
if ($Base -notmatch '^https?://') { throw "Base must be a URL, e.g. https://weareon.net (got: $Base)" }
[Net.ServicePointManager]::DefaultConnectionLimit = 2000
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$viewer = {
  param($Base, $Seconds, $Heartbeat, $Ramp, $Event, $T0)
  Add-Type -AssemblyName System.Net.Http
  $rnd = New-Object System.Random
  Start-Sleep -Milliseconds ([int]($rnd.NextDouble() * $Ramp * 1000))
  $http = New-Object System.Net.Http.HttpClient
  $http.Timeout = [TimeSpan]::FromSeconds(15)
  $out = New-Object System.Collections.Generic.List[object]
  $hit = {
    param($name, $url, $body)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
      if ($body) { $c = New-Object System.Net.Http.StringContent($body, [Text.Encoding]::UTF8, 'application/json'); $r = $http.PostAsync($url, $c).Result }
      else { $r = $http.GetAsync($url).Result }
      $null = $r.Content.ReadAsStringAsync().Result; $code = [int]$r.StatusCode
    } catch { $e = $_.Exception; while ($e.InnerException) { $e = $e.InnerException }; if ($sw.ElapsedMilliseconds -ge 14500) { $code = 'Timeout15s' } elseif ($e.Message -match 'forcibly|aborted|closed|empty') { $code = 'EmptyResponse' } else { $code = $e.GetType().Name } }
    $out.Add([pscustomobject]@{ ep = $name; code = $code; ms = $sw.ElapsedMilliseconds; sec = [int]((Get-Date) - $T0).TotalSeconds })
  }
  & $hit 'index' "$Base/?e=$Event"; & $hit 'config.json' "$Base/data/config.json"; & $hit 'app.js' "$Base/js/app.js"; & $hit 'styles.css' "$Base/css/styles.css"
  $id = -join ((1..16) | ForEach-Object { '{0:x}' -f $rnd.Next(16) })
  $json = '{"id":"' + $id + '","event":"' + $Event + '","scene":"main","tech":"webrtc"}'
  while (((Get-Date) - $T0).TotalSeconds -lt $Seconds) {
    & $hit 'presence POST' "$Base/admin/presence.php" $json
    Start-Sleep -Milliseconds ([int](($Heartbeat + $rnd.NextDouble() * 2) * 1000))
  }
  $http.Dispose()
  $out
}

$t0 = Get-Date
$pool = [RunspaceFactory]::CreateRunspacePool(1, $Viewers); $pool.Open()
$jobs = 1..$Viewers | ForEach-Object {
  $ps = [PowerShell]::Create(); $ps.RunspacePool = $pool
  $null = $ps.AddScript($viewer).AddArgument($Base).AddArgument($Seconds).AddArgument($Heartbeat).AddArgument($Ramp).AddArgument($Event).AddArgument($t0)
  @{ ps = $ps; h = $ps.BeginInvoke() }
}
Write-Host "$Base  viewers=$Viewers  duration=${Seconds}s  heartbeat=${Heartbeat}s  (all from one IP) ..."
$rows = foreach ($j in $jobs) { $j.ps.EndInvoke($j.h); $j.ps.Dispose() }
$pool.Close()

$ok = $true
"{0,-14} {1,6} {2,6} {3,6}  {4,-12} {5}" -f 'endpoint', 'count', 'ok', 'failed', 'p50/p95 ms', 'error codes'
foreach ($g in ($rows | Group-Object ep)) {
  $n = $g.Count; $good = @($g.Group | Where-Object { $_.code -eq 200 -or $_.code -eq 204 }).Count; $bad = $n - $good
  $l = @($g.Group.ms | Sort-Object); $p50 = $l[[int]($l.Count / 2)]; $p95 = $l[[Math]::Min($l.Count - 1, [int]($l.Count * 0.95))]
  $errs = ($g.Group | Where-Object { $_.code -ne 200 -and $_.code -ne 204 } | Group-Object code | ForEach-Object { "$($_.Name)x$($_.Count)" }) -join ', '
  if ($bad) { $ok = $false }
  "{0,-14} {1,6} {2,6} {3,6}  {4,-12} {5}" -f $g.Name, $n, $good, $bad, "$p50/$p95", $errs
}
$perSec = $rows | Group-Object sec | ForEach-Object { $_.Count }
$failSec = $rows | Where-Object { $_.code -ne 200 -and $_.code -ne 204 } | Group-Object sec | Sort-Object { [int]$_.Name } | ForEach-Object { "$($_.Name)s×$($_.Count)" }
if ($failSec) { "failures by second: " + ($failSec -join ", ") }
"requests/s: average {0:N1}, peak {1}" -f ($rows.Count / [Math]::Max(1, $Seconds)), (($perSec | Measure-Object -Maximum).Maximum)
if ($ok) { 'RESULT: OK, no rejections'; exit 0 } else { 'RESULT: FAIL: the host rejects or drops requests from one IP at this load'; exit 1 }
