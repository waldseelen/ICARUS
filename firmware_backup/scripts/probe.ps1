$src = @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class H {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string n,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("hid.dll")] static extern bool HidD_GetPreparsedData(SafeFileHandle h, out IntPtr p);
 [DllImport("hid.dll")] static extern bool HidD_FreePreparsedData(IntPtr p);
 [DllImport("hid.dll")] static extern int HidP_GetCaps(IntPtr p, out Caps c);
 [StructLayout(LayoutKind.Sequential)] public struct Caps { public ushort Usage, UsagePage, In, Out, Feat; [MarshalAs(UnmanagedType.ByValArray,SizeConst=17)] public ushort[] R; public ushort a,b,c,d,e,f,g,h,i,j; }
 public static string Probe(string path) {
  SafeFileHandle h = CreateFile(path,0,3,IntPtr.Zero,3,0,IntPtr.Zero);
  if (h.IsInvalid) return "open fail err=" + Marshal.GetLastWin32Error();
  IntPtr p; if(!HidD_GetPreparsedData(h,out p)) return "preparsed fail";
  Caps c; HidP_GetCaps(p,out c); HidD_FreePreparsedData(p); h.Close();
  return String.Format("UsagePage=0x{0:X} Usage=0x{1:X} In={2} Out={3} Feature={4}",c.UsagePage,c.Usage,c.In,c.Out,c.Feat);
 }
}
"@
Add-Type -TypeDefinition $src
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^HID\\VID_258A' } | ForEach-Object {
  $p = '\\?\' + ($_.InstanceId -replace '\\','#') + '#{4d1e55b2-f16f-11cf-88cb-001111000030}'
  "{0} -> {1}" -f $_.InstanceId, [H]::Probe($p)
}
