
{ fetchBit
, runCommand
}:

url: byteNum:

let
  f = bitOffset: fetchBit url (byteNum * 8 + bitOffset);

  l = builtins.genList f 8;
in
runCommand
  "fetchByte"
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
  '';
