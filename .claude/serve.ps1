param([string]$Root = ".", [int]$Port = 8765)
$Root = (Resolve-Path $Root).Path
$mime = @{ ".html"="text/html; charset=utf-8"; ".htm"="text/html; charset=utf-8"; ".css"="text/css; charset=utf-8"; ".js"="application/javascript; charset=utf-8";
  ".svg"="image/svg+xml"; ".png"="image/png"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".webp"="image/webp"; ".ico"="image/x-icon";
  ".json"="application/json; charset=utf-8"; ".woff"="font/woff"; ".woff2"="font/woff2"; ".txt"="text/plain; charset=utf-8"; ".md"="text/plain; charset=utf-8"; ".webmanifest"="application/manifest+json" }
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root on http://localhost:$Port/"
while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $req = $ctx.Request; $res = $ctx.Response
  try {
    $rel = [Uri]::UnescapeDataString($req.Url.AbsolutePath).TrimStart('/')
    if ($req.HttpMethod -eq "POST" -and $rel -like "__save/*") {
      $name = $rel.Substring(7)
      if ($name -notmatch '^[A-Za-z0-9_.-]+.png$') { $res.StatusCode = 400; $res.OutputStream.Close(); continue }
      $dir = Join-Path $Root "logo/png"; if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
      $ms = New-Object IO.MemoryStream; $req.InputStream.CopyTo($ms)
      [IO.File]::WriteAllBytes((Join-Path $dir $name), $ms.ToArray())
      $b = [Text.Encoding]::UTF8.GetBytes("saved " + $ms.Length); $res.OutputStream.Write($b,0,$b.Length); $res.OutputStream.Close(); continue
    }
    if ($rel -eq "") { $rel = "index.html" }
    $path = Join-Path $Root $rel
    if ((Test-Path $path) -and (Get-Item $path).PSIsContainer) { $path = Join-Path $path "index.html" }
    if (Test-Path $path -PathType Leaf) {
      $ext = [IO.Path]::GetExtension($path).ToLower()
      $ct = $mime[$ext]; if (-not $ct) { $ct = "application/octet-stream" }
      $bytes = [IO.File]::ReadAllBytes($path)
      $res.ContentType = $ct; $res.ContentLength64 = $bytes.Length
      $res.Headers.Add("Cache-Control","no-store")
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else {
      $res.StatusCode = 404
      $b = [Text.Encoding]::UTF8.GetBytes("404 Not Found: $rel"); $res.OutputStream.Write($b,0,$b.Length)
    }
  } catch { $res.StatusCode = 500 } finally { $res.OutputStream.Close() }
}
