
{ fetchByte
, runCommand
}:

url: bytes:

let
  l = builtins.genList (fetchByte url) bytes;
in
runCommand
  "fetchBytes"
  {
    passAsFile = [ "allByteDrvs" ];
    allByteDrvs = l;
  }
  ''
    (tr ' ' '\n' < "$allByteDrvsPath" ; echo) | while read -r line ; do
      head -c1 "$line" >> $out
    done
  ''
