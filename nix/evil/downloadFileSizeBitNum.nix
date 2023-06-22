
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
    if SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt" "''${curl[@]}" "${url}" > ./downloaded_file; then

      # The size of the file in bytes as a decimal string.
      # Example: "260"
      file_size_decimal=$(stat --printf="%s" ./downloaded_file)

      # The size of the file in bytes as a binary string.
      # Example: "100000100"
      file_size_binary=$(echo "ibase=10; obase=2; $file_size_decimal" | bc)

      # The number of bits required to represent the file size of the file
      # we're trying to download.
      # Example: "9"
      file_size_actual_total_bits="''${#file_size_binary}"

      if [ "$file_size_actual_total_bits" -gt "${toString fileSizeTotalBits}" ]; then
        echo "Trying to download the file ${url}, which has a file size of $file_size_decimal bytes."
        echo "However, this takes $file_size_actual_total_bits bits to represent, which is larger than"
        echo "${toString fileSizeTotalBits} bits, the maximum allowed."
        exit 1
      fi

      # The size of the file padded with zeros so that it is 16 bits.
      # Example: "0000000100000100"
      file_size_binary_padded=$(printf '%16s' "$file_size_binary" | tr ' ' 0)

      # The bit of the filesize that we are looking for.  For example,
      # given the above file size in biary, if we are looking for the 14th bit
      # (bit with index 13), this would be "1".
      bit_char="$(echo "$file_size_binary_padded" | tail -c +${toString (bitNum + 1)} | head -c1)"

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
