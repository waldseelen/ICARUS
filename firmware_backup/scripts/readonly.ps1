$src = @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class R {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string n,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("hid.dll")] static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, uint l);
 [DllImport("hid.dll")] static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, uint l);
 public static SafeFileHandle Open(string p){ return CreateFile(p,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); }
 public static string Cmd(SafeFileHandle c, byte op){
  byte[] s = new byte[]{5,op,0,0,0,0};
  if(!HidD_SetFeature(c,s,6)) return "SET_FAIL err="+Marshal.GetLastWin32Error();
  byte[] g = new byte[6]; g[0]=5;
  if(!HidD_GetFeature(c,g,6)) return "GET_FAIL err="+Marshal.GetLastWin32Error();
  return BitConverter.ToString(g);
 }
 public static string Blk(SafeFileHandle d){
  byte[] b = new byte[520]; b[0]=4;
  if(!HidD_GetFeature(d,b,520)) return "GET_FAIL err="+Marshal.GetLastWin32Error();
  return Convert.ToBase64String(b);
 }
}
"@
Add-Type -TypeDefinition $src
function P($col,$id){ '\\?\hid#vid_258a&pid_0027&mi_01&' + $col + '#' + $id + '#{4d1e55b2-f16f-11cf-88cb-001111000030}' }
$c = [R]::Open((P 'col05' '8&9fde8ee&0&0004'))
$d = [R]::Open((P 'col03' '8&9fde8ee&0&0002'))
if($c.IsInvalid -or $d.IsInvalid){ "OPEN_FAIL cmd=$($c.IsInvalid) data=$($d.IsInvalid)"; exit }
"PSD " + [R]::Cmd($c,1)
"ACTIVE " + [R]::Cmd($c,2)
foreach($op in 0x11,0x12,0x21,0x22){
  $r = [R]::Cmd($c,$op)
  "ARM_{0:X2} {1}" -f $op,$r
  "BLK_{0:X2} {1}" -f $op,[R]::Blk($d)
}
