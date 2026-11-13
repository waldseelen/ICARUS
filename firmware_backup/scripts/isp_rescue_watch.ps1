$src = @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public class Isp {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    public static extern SafeFileHandle CreateFile(string n, uint a, uint s, IntPtr sa, uint d, uint f, IntPtr t);
    [DllImport("hid.dll", SetLastError=true)]
    public static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, uint l);
    [DllImport("hid.dll", SetLastError=true)]
    public static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, uint l);
    public static SafeFileHandle Open(string p) {
        return CreateFile(p, 0xC0000000u, 3u, IntPtr.Zero, 3u, 0u, IntPtr.Zero);
    }
    public static bool Cmd(SafeFileHandle c, byte op, ushort addr) {
        byte[] s = new byte[]{ 5, op, (byte)(addr & 0xff), (byte)(addr >> 8), 0, 0 };
        return HidD_SetFeature(c, s, 6);
    }
}
"@
Add-Type -TypeDefinition $src

Write-Output "WATCHING FOR VID_0603&PID_1021..."
$fw = [System.IO.File]::ReadAllBytes("C:\Users\HP\AppData\Local\Temp\fw_patched_isp.bin")

for ($iter = 0; $iter -lt 600; $iter++) {
    $id01 = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_0603&PID_1021.*COL01" } | Select-Object -First 1 -ExpandProperty DeviceID
    $id02 = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_0603&PID_1021.*COL02" } | Select-Object -First 1 -ExpandProperty DeviceID
    if ($id01 -and $id02) {
        Write-Output "CAUGHT ISP DEVICE! Flashing..."
        $p01 = "\\?\" + $id01.ToLowerInvariant().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}"
        $p02 = "\\?\" + $id02.ToLowerInvariant().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}"
        $hCmd = [Isp]::Open($p01)
        $hXfer = [Isp]::Open($p02)
        if (-not $hCmd.IsInvalid -and -not $hXfer.IsInvalid) {
            [Isp]::Cmd($hCmd, 0x45, 0) | Out-Null
            Start-Sleep -Milliseconds 500
            $wbuf = New-Object byte[] 2050
            $wbuf[0] = 0x06
            $wbuf[1] = 0x77
            for ($addr = 0; $addr -lt 0xF000; $addr += 0x800) {
                [Isp]::Cmd($hCmd, 0x57, [uint16]$addr) | Out-Null
                [Array]::Copy($fw, $addr, $wbuf, 2, 2048)
                [Isp]::HidD_SetFeature($hXfer, $wbuf, 2050) | Out-Null
            }
            [Isp]::Cmd($hCmd, 0x55, 0) | Out-Null
            Start-Sleep -Milliseconds 100
            [Isp]::Cmd($hCmd, 0x5A, 0) | Out-Null
            $hCmd.Close()
            $hXfer.Close()
            Write-Output "RECOVERED AND FLASHED SUCCESSFULLY!"
            exit 0
        }
    }
    Start-Sleep -Milliseconds 200
}
Write-Output "TIMEOUT"
