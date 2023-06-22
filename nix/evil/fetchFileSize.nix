
{ fetchFileSizeBit
, fileSizeTotalBits
, runCommand
}:

# Similar to ./fetchBytes.nix and ./fetchByte.nix, but instead fetch
# the file size of the given URL, and write it as an ASCII decimal
# string to a file.
#
# This derivation outputs a single file that looks something like
# the following:
#
# ```
# 398
# ```
#
# This would represent a file that was 398 bytes long.


# URL to figure out the file size of.
# Example: "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
url:

let
  urlHash = builtins.hashString "sha256" url;

  f = fileSizeBit: fetchFileSizeBit url urlHash fileSizeBit;

  # A list of derivations, each containing one bit value of the file size of
  # the URL we want to download.
  l = builtins.genList f fileSizeTotalBits;
in
runCommand
  "fetchFileSize-${urlHash}-${toString fileSizeTotalBits}"
  {
    passAsFile = [ "allBitDrvs" ];
    allBitDrvs = l;
  }
  ''
    (tr ' ' '\n' < "$allBitDrvsPath" ; echo) | while read -r line ; do
      tr --delete '\n' < "$line" >> ./fileSizeBitValues
    done

    bits="$(cat ./fileSizeBitValues)"
    echo "$((2#$bits))" > "$out"
  ''
