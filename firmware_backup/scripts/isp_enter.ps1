$src = @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class E {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string n,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("hid.dll")] static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, uint l);
 public static SafeFileHandle Open(string p){ return CreateFile(p,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); }
 public static string Enter(SafeFileHandle c){
  byte[] s = new byte[]{5,0x75,0,0,0,0};
  if(!HidD_SetFeature(c,s,6)) return "SET_FAIL err="+Marshal.GetLastWin32Error();
  return "SET_OK";
 }
}
"@
Add-Type -TypeDefinition $src
$c = [E]::Open('\\?\hid#vid_258a&pid_0027&mi_01&col05#8&9fde8ee&0&0004#{4d1e55b2-f16f-11cf-88cb-001111000030}')
if($c.IsInvalid){ "OPEN_FAIL err=$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"; exit 1 }
"ENTER " + [E]::Enter($c)
