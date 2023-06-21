
# See ./downloadBitNum.nix for more documentation.

{ bc
, cacert
, collisions
, curl
, # The total number of bits to use for a file size.
  # Example: 16 (which would be 2 bytes)
  fileSizeTotalBits
, lib
, stdenv
, xxd
}:

# This produces a FOD that downloads the specified bit of the file size of a
# given URL. The output is one of two PDF files.  This is similar to
# ./downloadBitNum.nix, but it outputs a bit corresponding to the file size,
# instead of the content of the file to be downloaded.

{ url, urlHash, bitNum, bitNumStr }:

stdenv.mkDerivation {

  name = "downloadFileSizeBitNum-${urlHash}-${bitNumStr}";
  inherit url;

  outputHash = collisions.sha1;
  outputHashMode = "flat";
  outputHashAlgo = "sha1";

  nativeBuildInputs = [ curl bc xxd ];
  preferLocalBuild = true;

  inherit (collisions) bitValue1Pdf bitValue0Pdf;

  buildCommand = ''
    echo "Trying to download file size bitNum ${bitNumStr} for url: ${url}"
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
    # TODO: Is it possible to get curl to tell us the file size without having
    # to download the whole file? That might be a possible optimization.
    if SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt" "''${curl[@]}" "$url" > ./downloaded_file; then
      file_size_decimal=$(stat --printf="%s" ./downloaded_file)
      file_size_binary=$(echo "ibase=10; obase=2; $file_size_decimal" | bc)
      file_size_binary_padded=$(printf '%16s' "$file_size_binary" | tr ' ' 0)
      first_bit="$(echo "$file_size_binary_padded" | tail -c +${toString (bitNum + 1)} | head -c1)"
      if [ "$first_bit" == "1" ]; then
        cp "$bitValue1Pdf" "$out"
      elif [ "$first_bit" == "0" ]; then
        cp "$bitValue0Pdf" "$out"
      else
        echo "Got unexpected bit value: $first_bit"
        exit 1
      fi
    else
      echo "Failed to download file"
      exit 1
    fi
  '';

  impureEnvVars = lib.fetchers.proxyImpureEnvVars;
}
