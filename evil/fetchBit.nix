
{ runCommand, downloadBitNum, collisions }:

url: bitNum:

let
  urlHash = builtins.hashString "sha256" url;
  bitNumStr = toString bitNum;
in
runCommand
  "bitvalue-${urlHash}-${bitNumStr}"
  {
    result = downloadBitNum { inherit url urlHash bitNum bitNumStr; };
    inherit (collisions) bitValue1Pdf;
  }
  ''
    if cmp -s "$result" "$bitValue1Pdf"; then
      echo 1 > "$out"
    else
      echo 0 > "$out"
    fi
  ''
