
{ fetchBit
, runCommand
}:

# Similar to ./fetchBit.nix, but fetches a whole byte of the URL.


# URL string to download.
# Example: "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
url:

# Hash of the URL to download.
# Example: "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
urlHash:

# The byte index to download (starting from 0).
# Example: 123
byteNum:

let
  f = bitOffset: fetchBit url urlHash (byteNum * 8 + bitOffset);

  # A list of 8 derivations, each of which fetches a single bit.
  l = builtins.genList f 8;
in
runCommand
  "fetchByte-${urlHash}-${toString byteNum}"
  {
    passAsFile = [ "allBitDrvs" ];
    allBitDrvs = l;
  }
  ''
    # Read the list of derivations, each of which should contain a single file
    # with a single ascii character "1" or "0".  Loop over files in this list,
    # and write the individual bit characters to the file ./bitValues.
    (tr ' ' '\n' < "$allBitDrvsPath" ; echo) | while read -r line ; do
      tr --delete '\n' < "$line" >> ./bitValues
    done

    # Read in the bit string that represents this bit we are trying to download.
    # Example: "00100011"
    bits="$(cat ./bitValues)"

    # Convert this bit string do a decimal number:
    # Example: "35"
    decimal="$((2#$bits))"

    # Convert this decimal number to a hex number:
    # Example: "23"
    hex="$(printf '%x' $decimal)"

    # Convert this hex number to a raw byte, and write it to a file.
    printf '%b' "\\x$hex" > $out
  ''
