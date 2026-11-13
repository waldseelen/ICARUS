$src = @"
using System; using System.Runtime.InteropServices; using Microsoft.Win32.SafeHandles;
public class R {
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string n,uint a,uint s,IntPtr sa,uint d,uint f,IntPtr t);
 [DllImport("hid.dll")] static extern bool HidD_SetFeature(SafeFileHandle h, byte[] b, uint l);
 [DllImport("hid.dll")] static extern bool HidD_GetFeature(SafeFileHandle h, byte[] b, uint l);
 public static SafeFileHandle Open(string p){ return CreateFile(p,0xC0000000,3,IntPtr.Zero,3,0,IntPtr.Zero); }
 public static string SetCmd(SafeFileHandle c, byte op, byte a0){
  byte[] s = new byte[]{5,op,a0,0,0,0};
  if(!HidD_SetFeature(c,s,6)) return "SET_FAIL err="+Marshal.GetLastWin32Error();
  return "ok";
 }
 public static string GetCmd(SafeFileHandle c){
  byte[] g = new byte[6]; g[0]=5;
  if(!HidD_GetFeature(c,g,6)) return "GET_FAIL err="+Marshal.GetLastWin32Error();
  return BitConverter.ToString(g);
 }
 public static string Write(SafeFileHandle d, byte[] b){
  for(int i=0;i<3;i++){ if(HidD_SetFeature(d,b,520)) return "ok"; System.Threading.Thread.Sleep(200); }
  return "WRITE_FAIL err="+Marshal.GetLastWin32Error();
 }
 public static byte[] Blk(SafeFileHandle d){
  byte[] b = new byte[520]; b[0]=4;
  if(!HidD_GetFeature(d,b,520)) return null;
  return b;
 }
}
"@
Add-Type -TypeDefinition $src
$T = $env:TEMP
function P($col,$id){ '\\?\hid#vid_258a&pid_0027&mi_01&' + $col + '#' + $id + '#{4d1e55b2-f16f-11cf-88cb-001111000030}' }
$c = [R]::Open((P 'col05' '8&9fde8ee&0&0004'))
$d = [R]::Open((P 'col03' '8&9fde8ee&0&0002'))
if($c.IsInvalid -or $d.IsInvalid){ "OPEN_FAIL"; exit 1 }
function FX($n){ ,[Convert]::FromBase64String((Get-Content "$T\fx_$n.b64" -Raw).Trim()) }
$plan = @( ,@("p1_b2",0x50) )
foreach($e in $plan){
  $b = [byte[]](FX $e[0]); $b[3] = [byte]$e[1]
  "WRITE {0} magic=0x{1:X2} -> {2}" -f $e[0],$e[1],[R]::Write($d,$b)
}
Start-Sleep -Milliseconds 20
"SET_ACTIVE 2 -> " + [R]::SetCmd($c,2,2)
Start-Sleep -Milliseconds 200
"SET_ACTIVE 1 -> " + [R]::SetCmd($c,2,1)
Start-Sleep -Milliseconds 500
[void][R]::SetCmd($c,2,0); Start-Sleep -Milliseconds 50
"ACTIVE_READ " + [R]::GetCmd($c)
$ops = @{ 'p1_b1'=0x11; 'p1_b2'=0x12; 'p2_b1'=0x21; 'p2_b2'=0x22 }
foreach($n in 'p1_b1','p1_b2','p2_b1','p2_b2'){
  [void][R]::SetCmd($c,[byte]$ops[$n],0); Start-Sleep -Milliseconds 50
  $r = [R]::Blk($d)
  if($r -eq $null){ "READ_FAIL $n"; continue }
  $f = [byte[]](FX $n)
  $diff = 0; for($i=0;$i -lt 520;$i++){ if($i -eq 3){continue}; if($r[$i] -ne $f[$i]){ $diff++ } }
  "VERIFY {0}: diffs={1}" -f $n,$diff
}
