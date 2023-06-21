
{ fetchFileSizeBit
, fileSizeTotalBits
, runCommand
}:

url:

let
  urlHash = builtins.hashString "sha256" url;

  f = fileSizeBit: fetchFileSizeBit url urlHash fileSizeBit;

  l = builtins.genList f fileSizeTotalBits;
in
runCommand
  "fetchFileSize-${urlHash}-${toString fileSizeTotalBits}"
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
