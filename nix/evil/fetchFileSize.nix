
{ fetchFileSizeBit
, fileSizeTotalBits
, runCommand
}:

url:

let
  f = fileSizeBit: fetchFileSizeBit url fileSizeBit;
  l = builtins.genList f fileSizeTotalBits;
in
runCommand
  "fetchFileSize"
  {
    passAsFile = [ "allBitDrvs" ];
    allBitDrvs = l;
  }
  ''
    (tr ' ' '\n' < "$allBitDrvsPath" ; echo) | while read -r line ; do
      tr --delete '\n' < "$line" >> ./fileSizeBitValues
    done

    bits="$(cat ./fileSizeBitValues)"
    echo "$((2#$bits))" > "$out"
  ''
