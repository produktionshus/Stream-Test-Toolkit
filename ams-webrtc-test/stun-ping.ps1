# STUN "ping": sender en STUN Binding Request (RFC 5389) over UDP og viser svaret.
# Brug:  powershell -ExecutionPolicy Bypass -File stun-ping.ps1            (Google STUN, som streamingen bruger)
#        powershell -ExecutionPolicy Bypass -File stun-ping.ps1 turn.weareon.net 5555
param([string]$Server = 'stun.l.google.com', [int]$Port = 19302, [int]$TimeoutMs = 3000)

$req = New-Object byte[] 20
$req[0] = 0x00; $req[1] = 0x01                       # Binding Request
$req[2] = 0x00; $req[3] = 0x00                       # length 0
$req[4] = 0x21; $req[5] = 0x12; $req[6] = 0xA4; $req[7] = 0x42   # magic cookie
$tid = New-Object byte[] 12; (New-Object Random).NextBytes($tid); [Array]::Copy($tid, 0, $req, 8, 12)   # transaction id

$udp = New-Object System.Net.Sockets.UdpClient
$udp.Client.ReceiveTimeout = $TimeoutMs
try {
  $ip = [System.Net.Dns]::GetHostAddresses($Server) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
  "$Server -> $ip`:$Port  (UDP)"
  $sw = [Diagnostics.Stopwatch]::StartNew()
  [void]$udp.Send($req, 20, $ip.ToString(), $Port)
  $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
  $res = $udp.Receive([ref]$ep)
  $sw.Stop()
  if ($res.Length -lt 20 -or $res[0] -ne 0x01 -or $res[1] -ne 0x01) { "SVAR modtaget, men ikke en Binding Success ($($res.Length) bytes)"; exit 2 }
  # find XOR-MAPPED-ADDRESS (0x0020) eller MAPPED-ADDRESS (0x0001)
  $pos = 20; $pub = $null
  while ($pos + 4 -le $res.Length) {
    $type = ($res[$pos] -shl 8) -bor $res[$pos+1]; $len = ($res[$pos+2] -shl 8) -bor $res[$pos+3]; $v = $pos + 4
    if ($type -eq 0x0020 -and $res[$v+1] -eq 1) {
      $p = ((($res[$v+2] -shl 8) -bor $res[$v+3]) -bxor 0x2112)
      $a = @(($res[$v+4] -bxor 0x21), ($res[$v+5] -bxor 0x12), ($res[$v+6] -bxor 0xA4), ($res[$v+7] -bxor 0x42)) -join '.'
      $pub = "$a`:$p"
    } elseif ($type -eq 0x0001 -and $res[$v+1] -eq 1 -and -not $pub) {
      $pub = "$($res[$v+4]).$($res[$v+5]).$($res[$v+6]).$($res[$v+7]):$((($res[$v+2] -shl 8) -bor $res[$v+3]))"
    }
    $pos = $v + $len + ((4 - $len % 4) % 4)
  }
  "OK  Binding Success fra $($ep.Address) efter $($sw.ElapsedMilliseconds) ms. Din offentlige adresse set udefra: $pub"
  exit 0
} catch {
  "FEJL  intet svar fra $Server`:$Port inden for $TimeoutMs ms  ($($_.Exception.Message))"
  "      UDP $Port udgaaende er sandsynligvis blokeret, eller svaret kommer ikke tilbage gennem VPN/firewall."
  exit 1
} finally { $udp.Close() }
