
{ runCommand
, downloadBitNum
, collisions
, drvNamePrefix ? ""
}:

url: bitNum:

let
  urlHash = builtins.hashString "sha256" url;

  bitNumStr = toString bitNum;

  drvNamePrefix' = if drvNamePrefix == "" then "" else "${drvNamePrefix}-";

  bitNumResult = downloadBitNum { inherit url urlHash bitNum bitNumStr; };

  inherit (collisions) bitValue1Pdf;
in
runCommand
  "${drvNamePrefix'}bitvalue-${urlHash}-${bitNumStr}"
  {}
  ''
    if cmp -s "${bitNumResult}" "${bitValue1Pdf}"; then
      echo 1 > "$out"
    else
      echo 0 > "$out"
    fi
  ''
