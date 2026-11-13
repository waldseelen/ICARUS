$src = @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class I {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string n,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("hid.dll")] static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, uint l);
 [DllImport("hid.dll")] static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, uint l);
 public static SafeFileHandle Open(string p){ return CreateFile(p,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); }
 public static string Set(SafeFileHandle c, byte op, ushort addr){
  byte[] s = new byte[]{5,op,(byte)(addr & 0xff),(byte)(addr >> 8),0,0};
  if(!HidD_SetFeature(c,s,6)) return "SET_FAIL err="+Marshal.GetLastWin32Error();
  return "SET_OK";
 }
 public static string Get(SafeFileHandle d){
  byte[] b = new byte[2050]; b[0]=6;
  if(!HidD_GetFeature(d,b,2050)) return "GET_FAIL err="+Marshal.GetLastWin32Error();
  string head = BitConverter.ToString(b,0,16);
  return "GET_OK head=" + head;
 }
}
"@
Add-Type -TypeDefinition $src
$cmd = [I]::Open('\\?\hid#vid_0603&pid_1021&col01#7&2cb25759&0&0000#{4d1e55b2-f16f-11cf-88cb-001111000030}')
$xfer = [I]::Open('\\?\hid#vid_0603&pid_1021&col02#7&2cb25759&0&0001#{4d1e55b2-f16f-11cf-88cb-001111000030}')
if($cmd.IsInvalid -or $xfer.IsInvalid){ "OPEN_FAIL cmd=$($cmd.IsInvalid) xfer=$($xfer.IsInvalid)"; exit 1 }
"INIT " + [I]::Set($cmd,0x52,0x0000)
"PAGE " + [I]::Get($xfer)
