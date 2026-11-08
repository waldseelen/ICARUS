$src = @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class H {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern SafeFileHandle CreateFile(string p, uint a, uint s, IntPtr sa, uint d, uint f, IntPtr t);
    [DllImport("hid.dll", SetLastError=true)]
    public static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, int l);
    [DllImport("hid.dll", SetLastError=true)]
    public static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, int l);
    public static SafeFileHandle Open(string p) { return CreateFile(p, 0xC0000000u, 3u, IntPtr.Zero, 3u, 0u, IntPtr.Zero); }
}
"@
Add-Type -TypeDefinition $src

$p03 = '\\?\hid#vid_258a&pid_0027&mi_01&col03#8&1972966b&0&0002#{4d1e55b2-f16f-11cf-88cb-001111000030}'
$p05 = '\\?\hid#vid_258a&pid_0027&mi_01&col05#8&1972966b&0&0004#{4d1e55b2-f16f-11cf-88cb-001111000030}'

$h03 = [H]::Open($p03)
$h05 = [H]::Open($p05)
if ($h03.IsInvalid -or $h05.IsInvalid) { Write-Output "OPEN_FAIL"; exit 1 }

$cmd = [byte[]](0x05, 0x21, 0x00, 0x00, 0x00, 0x00)
[H]::HidD_SetFeature($h05, $cmd, 6) | Out-Null
$g = [byte[]](0x05, 0, 0, 0, 0, 0)
[H]::HidD_GetFeature($h05, $g, 6) | Out-Null
$buf = New-Object byte[] 520
$buf[0] = 0x04
[H]::HidD_GetFeature($h03, $buf, 520) | Out-Null
Write-Output ("BEFORE: b8={0:X2} b9={1:X2} b10={2:X2} b11={3:X2} b12={4:X2} b130={5:X2} b131={6:X2}" -f $buf[8], $buf[9], $buf[10], $buf[11], $buf[12], $buf[130], $buf[131])

# Write p2_b1 with b8 = 0x00, b11 = 0x38
$wbuf = [byte[]]$buf.Clone()
$wbuf[8] = 0x00
$wbuf[11] = 0x38
[H]::HidD_SetFeature($h03, $wbuf, 520) | Out-Null
Start-Sleep -Milliseconds 250

[H]::HidD_SetFeature($h05, $cmd, 6) | Out-Null
[H]::HidD_GetFeature($h05, $g, 6) | Out-Null
$vbuf = New-Object byte[] 520
$vbuf[0] = 0x04
[H]::HidD_GetFeature($h03, $vbuf, 520) | Out-Null
Write-Output ("WRITTEN: b8={0:X2} b9={1:X2} b10={2:X2} b11={3:X2} b12={4:X2}" -f $vbuf[8], $vbuf[9], $vbuf[10], $vbuf[11], $vbuf[12])

# Enter ISP and reboot to run boot sequence 0x3943 -> 0x4FE3 -> 0x420C -> 0x4A2E
$isp = [byte[]](0x05, 0x75, 0x00, 0x00, 0x00, 0x00)
[H]::HidD_SetFeature($h05, $isp, 6) | Out-Null
$h03.Close()
$h05.Close()
Start-Sleep -Milliseconds 1200

$id = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_0603&PID_1021.*COL01" } | Select-Object -First 1 -ExpandProperty DeviceID
if ($id) {
    $isp01 = "\\?\" + $id.ToLower().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}"
    $hisp = [H]::Open($isp01)
    $reb = [byte[]](0x05, 0x5A, 0x00, 0x00, 0x00, 0x00)
    [H]::HidD_SetFeature($hisp, $reb, 6) | Out-Null
    $hisp.Close()
    Write-Output "ISP_REBOOT_OK"
}
Start-Sleep -Milliseconds 1500

$h03 = [H]::Open($p03)
$h05 = [H]::Open($p05)

[H]::HidD_SetFeature($h05, $cmd, 6) | Out-Null
[H]::HidD_GetFeature($h05, $g, 6) | Out-Null
$abuf = New-Object byte[] 520
$abuf[0] = 0x04
[H]::HidD_GetFeature($h03, $abuf, 520) | Out-Null
Write-Output ("AFTER_REBOOT: b8={0:X2} b9={1:X2} b10={2:X2} b11={3:X2} b12={4:X2}" -f $abuf[8], $abuf[9], $abuf[10], $abuf[11], $abuf[12])

if ($abuf[11] -ne 0x28) {
    [H]::HidD_SetFeature($h03, $buf, 520) | Out-Null
    Start-Sleep -Milliseconds 250
}
$h03.Close()
$h05.Close()
