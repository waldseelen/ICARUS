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

# 1. Enter ISP mode if currently 258A:0027
$dev05 = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_258A&PID_0027.*COL05" } | Select-Object -First 1 -ExpandProperty DeviceID
if ($dev05) {
    $p05 = "\\?\" + $dev05.ToLowerInvariant().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}"
    $h05 = [Isp]::Open($p05)
    if (-not $h05.IsInvalid) {
        $enter = [byte[]](0x05, 0x75, 0x00, 0x00, 0x00, 0x00)
        [Isp]::HidD_SetFeature($h05, $enter, 6) | Out-Null
        $h05.Close()
        Write-Output "ENTERED_ISP"
        Start-Sleep -Milliseconds 1500
    }
}

# 2. Open ISP COL01 (Report 0x05) and COL02 (Report 0x06)
$id01 = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_0603&PID_1021.*COL01" } | Select-Object -First 1 -ExpandProperty DeviceID
$id02 = Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -match "VID_0603&PID_1021.*COL02" } | Select-Object -First 1 -ExpandProperty DeviceID
if (-not $id01 -or -not $id02) {
    Write-Output "ISP_DEVICES_NOT_FOUND"
    exit 1
}
$p01 = "\\?\" + $id01.ToLowerInvariant().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}"
$p02 = "\\?\" + $id02.ToLowerInvariant().Replace("\", "#") + "#{4d1e55b2-f16f-11cf-88cb-001111000030}"
$hCmd = [Isp]::Open($p01)
$hXfer = [Isp]::Open($p02)
if ($hCmd.IsInvalid -or $hXfer.IsInvalid) {
    Write-Output "ISP_OPEN_FAIL"
    exit 1
}

$fw = [System.IO.File]::ReadAllBytes("C:\Users\HP\AppData\Local\Temp\fw_patched_isp.bin")
$orig = [System.IO.File]::ReadAllBytes("C:\Users\HP\AppData\Local\Temp\fw_patched_orig.bin")

# 3. Erase Flash (0x45)
Write-Output "ERASING_FLASH..."
if (-not [Isp]::Cmd($hCmd, 0x45, 0)) {
    Write-Output ("ERASE_FAIL err=" + [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    exit 1
}
Start-Sleep -Milliseconds 500

# 4. Write all 30 pages (0x0000..0xEFFF)
$wbuf = New-Object byte[] 2050
$wbuf[0] = 0x06
$wbuf[1] = 0x77
for ($addr = 0; $addr -lt 0xF000; $addr += 0x800) {
    if (-not [Isp]::Cmd($hCmd, 0x57, [uint16]$addr)) {
        Write-Output ("INIT_WRITE_FAIL addr={0:X4} err={1}" -f $addr, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
        exit 1
    }
    [Array]::Copy($fw, $addr, $wbuf, 2, 2048)
    if (-not [Isp]::HidD_SetFeature($hXfer, $wbuf, 2050)) {
        Write-Output ("PAGE_WRITE_FAIL addr={0:X4} err={1}" -f $addr, [Runtime.InteropServices.Marshal]::GetLastWin32Error())
        exit 1
    }
}
Write-Output "WRITE_30_PAGES_DONE"

# 5. Verify all 30 pages via 0x52 / 0x72
$rbuf = New-Object byte[] 2050
$mismatches = 0
for ($addr = 0; $addr -lt 0xF000; $addr += 0x800) {
    if (-not [Isp]::Cmd($hCmd, 0x52, [uint16]$addr)) {
        Write-Output ("INIT_READ_FAIL addr={0:X4}" -f $addr)
        exit 1
    }
    $rbuf[0] = 0x06
    if (-not [Isp]::HidD_GetFeature($hXfer, $rbuf, 2050)) {
        Write-Output ("PAGE_READ_FAIL addr={0:X4}" -f $addr)
        exit 1
    }
    for ($i = 0; $i -lt 2048; $i++) {
        $val = $rbuf[2 + $i]
        if ($i -ge 6) { $val = ($val - 0x5E) -band 0xFF }
        $exp = $orig[$addr + $i]
        if (($addr + $i) -eq 0xEFFB) { continue } # 0x55 sets 0xEFFB=0x02 next
        if ($val -ne $exp) {
            if ($mismatches -lt 10) {
                Write-Output ("MISMATCH at 0x{0:X4}: got=0x{1:X2} exp=0x{2:X2}" -f ($addr + $i), $val, $exp)
            }
            $mismatches++
        }
    }
}
Write-Output "VERIFY_DONE mismatches=$mismatches"

# 6. Enable Firmware (0x55 -> writes 0x02 to 0xEFFB)
[Isp]::Cmd($hCmd, 0x55, 0) | Out-Null
Start-Sleep -Milliseconds 100

# 7. Reboot (0x5A)
[Isp]::Cmd($hCmd, 0x5A, 0) | Out-Null
$hCmd.Close()
$hXfer.Close()
Write-Output "REBOOT_SENT"
