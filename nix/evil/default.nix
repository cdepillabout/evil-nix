
{runCommand, callPackage, lib}:

url:

let
  # The total number of bits to use to represent the file size.
  fileSizeTotalBits = 16;

  collisions = callPackage ./collisions.nix {};

  downloadBitNum = callPackage ./downloadBitNum.nix {
    inherit collisions;
  };

  downloadFileSizeBitNum = callPackage ./downloadFileSizeBitNum.nix {
    inherit collisions fileSizeTotalBits;
  };

  fetchBit = callPackage ./fetchBit.nix {
    inherit collisions downloadBitNum;
  };

  fetchFileSizeBit = callPackage ./fetchBit.nix {
    inherit collisions;
    downloadBitNum = downloadFileSizeBitNum;
    drvNamePrefix = "file-size";
  };

  fetchByte = url: byteNum:
    let
      f = bitOffset: fetchBit url (byteNum * 8 + bitOffset);

      l = builtins.genList f 8;
    in
    runCommand
      "lalal"
      {
        passAsFile = [ "allBitDrvs" ];
        allBitDrvs = l;
      }
      ''
        (tr ' ' '\n' < "$allBitDrvsPath" ; echo) | while read -r line ; do
          tr --delete '\n' < "$line" >> ./bitValues
        done

        bits="$(cat ./bitValues)"
        decimal="$((2#$bits))"
        hex="$(printf '%x' $decimal)"

        printf '%b' "\\x$hex" > $out
      '';

  fetchBytes = url: bytes:
    let
      l = builtins.genList (fetchByte url) bytes;
    in
    runCommand
      "lalal"
      {
        passAsFile = [ "allByteDrvs" ];
        allByteDrvs = l;
      }
      ''
        (tr ' ' '\n' < "$allByteDrvsPath" ; echo) | while read -r line ; do
          head -c1 "$line" >> $out
        done
      '';


  fetchFileSize = url:
    let
      f = fileSizeBit: fetchFileSizeBit url fileSizeBit;
      l = builtins.genList f fileSizeTotalBits;
    in
    runCommand
      "lalal"
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
      '';

  fileSize = import (fetchFileSize url);
in

fetchBytes url fileSize

# fetchFileSize url
# fetchBytes url 6

# runCommand
#   "lalal"
#   {}
#   ''
#     echo ${toString xxx} > $out
#   ''

# TODO: Change everything to work on bytes intead of bits!
# doFetch (1 * 8) (2 * 8)

# runCommand "test" {} ''
#   cp ${../README.md} $out
# ''
