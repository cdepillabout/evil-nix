
{ runCommand, downloadBitNum, collisions, drvNamePrefix ? "" }:

url: bitNum:

let
  urlHash = builtins.hashString "sha256" url;
  bitNumStr = toString bitNum;
  drvNamePrefix' = if drvNamePrefix == "" then "" else "${drvNamePrefix}-";
in
runCommand
  "${drvNamePrefix'}bitvalue-${urlHash}-${bitNumStr}"
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
