
{ cacert
, # A set of SHA1 collisions.  This should come from ./collisions.nix.
  collisions
, curl
, lib
, stdenv
, xxd
}:

# Download the specified bit of a URL.

{ url, urlHash, bitNum, bitNumStr }:

let
  byteNum = bitNum / 8;
  byteNumStr = toString byteNum;
  bitInByteNum = lib.mod bitNum 8;
in

stdenv.mkDerivation {

  name = "downloadBitNum-${urlHash}-${bitNumStr}";
  inherit url;

  outputHash = collisions.sha1;
  outputHashMode = "flat";
  outputHashAlgo = "sha1";

  nativeBuildInputs = [ curl xxd ];
  preferLocalBuild = true;

  inherit (collisions) bitValue1Pdf bitValue0Pdf;

  buildCommand = ''
    echo "Trying to download bitNum ${bitNumStr} which is bit ${toString bitInByteNum} in byteNum ${byteNumStr} for url: ${url}"
    curl=(
      curl
      --location
      --max-redirs 20
      --retry 3
      --disable-epsv
      --cookie-jar cookies
      --user-agent "curl evil-nix"
      --insecure
    )
    if SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt" "''${curl[@]}" "$url" > ./downloaded_file; then
      first_char="$(dd if=downloaded_file bs=1 count=1 skip=${byteNumStr} status=none | xxd -b | cut -d' ' -f2 | tail -c +${toString (bitInByteNum + 1)} | head -c1)"
      if [ "$first_char" == "1" ]; then
        cp "$bitValue1Pdf" "$out"
      elif [ "$first_char" == "0" ]; then
        cp "$bitValue0Pdf" "$out"
      else
        echo "Got unexpected bit value: $first_char"
        exit 1
      fi
    else
      echo "Failed to download file"
      exit 1
    fi
  '';

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;
}
