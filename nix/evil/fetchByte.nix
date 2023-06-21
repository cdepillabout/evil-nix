
{ fetchBit
, runCommand
}:

url: urlHash: byteNum:

let
  f = bitOffset: fetchBit url urlHash (byteNum * 8 + bitOffset);

  l = builtins.genList f 8;
in
runCommand
  "fetchByte-${urlHash}-${toString byteNum}"
  {
    passAsFile = [ "allBitDrvs" ];
    allBitDrvs = l;
  }
  ''
    (tr ' ' '\n' < "$allBitDrvsPath" ; echo) | while read -r line ; do
      tr --delete '\n' < "$line" >> ./bitValues
    done

    bits="$(cat ./bitValues)"
    decimal="$((2#$bits))"
    hex="$(printf '%x' $decimal)"

    printf '%b' "\\x$hex" > $out
  ''
