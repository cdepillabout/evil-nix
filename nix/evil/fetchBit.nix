
{ runCommand
, # Checkout ./downloadBitNum.nix and ./downloadFileSizeBitNum.nix for info
  # about this argument.
  downloadBitNum
, # Checkout ./collisions.nix for info about this.
  collisions
, # A prefix for the driver name.
  # This fetchBit derivation is used both for fetching bits corresponding
  # to the file's contents, as well as the file's size.  Use this prefix
  # to distinguish derivations.
  drvNamePrefix ? ""
}:

# Return a derivation that fetches a single bit from a given URL, using
# downloadBitNum to actually download the bit.  Create a single file that
# contains either a "1" or a "0" to represent the value of the bit.


# URL string to download.
# Example: "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
url:

# Hash of the URL to download.
# Example: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
urlHash:

# The bit number of the URL we will output.
# Example: 12
bitNum:

let
  bitNumStr = toString bitNum;

  drvNamePrefix' = if drvNamePrefix == "" then "" else "${drvNamePrefix}-";

  bitNumResult = downloadBitNum { inherit url urlHash bitNum bitNumStr; };

  inherit (collisions) bitValue1Pdf;
in
runCommand
  "${drvNamePrefix'}bitvalue-${urlHash}-${bitNumStr}"
  {}
  ''
    # Compare the contents of the PDF output by downloadBitNum.
    # If downloadBitNum output the PDF for the bit value 1, then
    # output a "1".  Otherwise, output a "0".
    if cmp -s "${bitNumResult}" "${bitValue1Pdf}"; then
      echo 1 > "$out"
    else
      echo 0 > "$out"
    fi
  ''
