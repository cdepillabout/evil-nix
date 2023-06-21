
{ fetchByte
, runCommand
}:

url: bytes:

let
  urlHash = builtins.hashString "sha256" url;

  l = builtins.genList (fetchByte url urlHash) bytes;
in
runCommand
  "fetchBytes-${urlHash}-${toString bytes}"
  {
    passAsFile = [ "allByteDrvs" ];
    allByteDrvs = l;
  }
  ''
    (tr ' ' '\n' < "$allByteDrvsPath" ; echo) | while read -r line ; do
      head -c1 "$line" >> $out
    done
  ''
