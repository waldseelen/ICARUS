$src = @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class D {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string n,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("hid.dll")] static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, uint l);
 [DllImport("hid.dll")] static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, uint l);
 public static SafeFileHandle Open(string p){ return CreateFile(p,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); }
 public static bool Set(SafeFileHandle c, byte op, ushort addr){
  byte[] s = new byte[]{5,op,(byte)(addr & 0xff),(byte)(addr >> 8),0,0};
  return HidD_SetFeature(c,s,6);
 }
 public static byte[] Page(SafeFileHandle d){
  byte[] b = new byte[2050]; b[0]=6;
  if(!HidD_GetFeature(d,b,2050)) return null;
  return b;
 }
}
"@
Add-Type -TypeDefinition $src
$cmd = [D]::Open('\\?\hid#vid_0603&pid_1021&col01#7&2cb25759&0&0000#{4d1e55b2-f16f-11cf-88cb-001111000030}')
$xfer = [D]::Open('\\?\hid#vid_0603&pid_1021&col02#7&2cb25759&0&0001#{4d1e55b2-f16f-11cf-88cb-001111000030}')
if($cmd.IsInvalid -or $xfer.IsInvalid){ "OPEN_FAIL cmd=$($cmd.IsInvalid) xfer=$($xfer.IsInvalid)"; exit 1 }
$ms = New-Object System.IO.MemoryStream
for($addr=0; $addr -lt 0x10000; $addr += 0x800){
  if(-not [D]::Set($cmd,0x52,[uint16]$addr)){ "INIT_FAIL $('{0:X4}' -f $addr)"; break }
  $b = [D]::Page($xfer)
  if($null -eq $b){ "PAGE_FAIL $('{0:X4}' -f $addr)"; break }
  if($b[0] -ne 6 -or $b[1] -ne 0x72){ "BAD_HDR $('{0:X4}' -f $addr) " + (BitConverter.ToString($b,0,8)); break }
  $ms.Write($b,2,2048)
  "PAGE $('{0:X4}' -f $addr) " + (BitConverter.ToString($b,2,8))
}
$out = 'C:\Users\HP\AppData\Local\Temp\isp_dump.bin'
[System.IO.File]::WriteAllBytes($out, $ms.ToArray())
"WROTE $($ms.Length) $out"
