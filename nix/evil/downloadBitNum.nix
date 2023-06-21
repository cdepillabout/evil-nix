
{ cacert
, # A set of SHA1 collisions.  This should come from ./collisions.nix.
  collisions
, curl
, lib
, stdenv
, xxd
}:

# This produces a FOD that downloads the specified bit of a URL.
# The output is one of two PDF files.  `collisions.bitValue1Pdf`
# is used to represent a `1` bit, while `collisions.bitValue0Pdf`
# is used to represent a `0` bit.

{ # URL to download.
  # Example: "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
  url
, # Hash of the URL to download.
  # Example: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  urlHash
, # The bit number of the URL we will output.
  # Example: 12
  bitNum
, # A string representation of the bit number
  # Example: "12"
  bitNumStr
}:

let
  # The index of the byte that contains this bit. For instance, when `bitNum`
  # is 19, `byteNum` is 2 (the 3rd byte).
  byteNum = bitNum / 8;

  byteNumStr = toString byteNum;

  # The index of the bit in the byte we want.  For instance, when `bitNum` is
  # 18, `bitInByteNum` is `3` (the 4th bit in the 3rd byte).
  bitInByteNum = lib.mod bitNum 8;
in

stdenv.mkDerivation {

  name = "downloadBitNum-${urlHash}-${bitNumStr}";

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

    # Download the requested URL to ./downloaded_file.
    #
    # TODO: It would be nice if we could have curl download JUST the requested
    # byte, and not the full file in every derivation.
    if SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt" "''${curl[@]}" "${url}" > ./downloaded_file; then

      # This convoluted command tries to figure out the value of the requested bit.
      bit_char="$(
        # Output the single raw byte we are looking for, using the byteNum
        # index into the file.
        dd if=downloaded_file bs=1 count=1 skip=${byteNumStr} status=none |
          # Turn the single raw byte into a binary string.  This outputs a
          # value like: "00000000: 00100011".
          xxd -b |
          # Cut out just the binary string.  This outputs a value like: "00100011".
          cut -d' ' -f2 |
          # Find the single bit we are looking for.  Assuming we're looking for the
          # 4th bit in this binary string, this outputs a value like: "00011"
          tail -c +${toString (bitInByteNum + 1)} |
          # Take the bit we're looking for.  This outputs a value like: "0"
          head -c1)"

      if [ "$bit_char" == "1" ]; then
        cp "$bitValue1Pdf" "$out"
      elif [ "$bit_char" == "0" ]; then
        cp "$bitValue0Pdf" "$out"
      else
        echo "Got unexpected bit value: $bit_char"
        exit 1
      fi

    else
      echo "Failed to download file"
      exit 1
    fi
  '';

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;
}
