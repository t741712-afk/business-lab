param(
  [string]$AdminPassword = "BusinessLab#2026"
)
# Frontal IIS (Windows Server 2022) con pagina de ejemplo. NO se une al dominio.
Start-Transcript -Path C:\prov.log -Append
try {
  net user Administrator $AdminPassword
  Enable-NetFirewallRule -Name FPS-ICMP4-ERQ-In   # ping (echo ICMPv4) para el monitor
  Install-WindowsFeature -Name Web-Server,Web-Asp-Net45 -IncludeManagementTools
  $html = @"
<!doctype html><html><head><meta charset='utf-8'><title>IIS Corp</title>
<style>body{font-family:Segoe UI;background:#3a1b3a;color:#ffeaff;margin:2rem}</style></head>
<body><h1>IIS &mdash; $env:COMPUTERNAME</h1>
<p>Windows Server 2022 &middot; frontal web corporativo</p>
<p>Fecha: $(Get-Date)</p></body></html>
"@
  Set-Content -Path C:\inetpub\wwwroot\index.html -Value $html -Encoding UTF8
  Remove-Item C:\inetpub\wwwroot\iisstart.htm -ErrorAction SilentlyContinue

  # VULNERABILIDAD (subida insegura de ficheros): el portal acepta cualquier extension
  # y guarda el fichero en una ruta servida por IIS, por lo que un .aspx se ejecuta
  New-Item -Path C:\inetpub\wwwroot\upload -ItemType Directory -Force | Out-Null
  $upload = @'
<%@ Page Language="C#" %>
<%@ Import Namespace="System.IO" %>
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>TAI Document Portal</title>
<style>body{font-family:Segoe UI;background:#0B0F19;color:#F3F4F6;margin:2rem}
h1 span{color:#06B6D4} .box{background:#0F172A;border:1px solid #1E293B;border-radius:8px;padding:1.5rem;max-width:720px}
button{background:#2563EB;color:#fff;border:none;padding:.5rem 1rem;border-radius:6px;font-weight:600}</style></head>
<body>
<h1>TAI <span>Document Portal</span></h1>
<div class="box">
<p>Upload research documents for the Berlin HQ review board.</p>
<form method="post" enctype="multipart/form-data">
  <input type="file" name="document" />
  <button type="submit">Upload</button>
</form>
<%
  if (Request.Files.Count > 0) {
    HttpPostedFile f = Request.Files[0];
    string dir = Server.MapPath("~/upload/files");
    Directory.CreateDirectory(dir);
    string name = Path.GetFileName(f.FileName);
    f.SaveAs(Path.Combine(dir, name));
    Response.Write("<p>Document stored at: /upload/files/" + name + "</p>");
  }
%>
</div>
</body>
</html>
'@
  Set-Content -Path C:\inetpub\wwwroot\upload\upload.aspx -Value $upload -Encoding UTF8
  icacls C:\inetpub\wwwroot\upload /grant "IIS_IUSRS:(OI)(CI)M" | Out-Null
  "iis ready" | Out-File C:\prov.done
} catch { $_ | Out-File C:\prov.error }
Stop-Transcript
