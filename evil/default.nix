
{runCommand, callPackage, lib}:

url:

let
  collisions = callPackage ./collisions.nix {};

  downloadBitNum = callPackage ./downloadBitNum.nix { inherit collisions; };

  fetchBit = callPackage ./fetchBit.nix { inherit collisions downloadBitNum; };

  # doFetch = startBit: stopBit:
  #   let
  #     f = bitNum: fetchBit url (bitNum + startBit);

  #     l = builtins.genList f (stopBit - startBit);
  #   in
  #   runCommand
  #     "lalal"
  #     {
  #       passAsFile = [ "allBitDrvs" ];
  #       allBitDrvs = l;
  #     }
  #     ''
  #       (tr ' ' '\n' < "$allBitDrvsPath" ; echo) | while read -r line ; do
  #         tr --delete '\n' < "$line" >> "$out"
  #       done
  #     '';

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

        set -x

        cat ./bitValues

        bits="$(cat ./bitValues)"
        decimal="$((2#$bits))"
        hex="$(printf '%x' $decimal)"

        echo $bits

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

  # fetchExample = doFetch (1 * 8) (2 * 8);

  # xxx = import fetchExample;


  # myurl = "https://raw.githubusercontent.com/WinMerge/winmerge/66e2ce0986d9a491a0b0ca1fe18df65c9b7b3cfd/Testing/Data/Compare1/Dir2/file2_1.txt";

  # myresultForBit = { bitValue }: fetchBit myurl bitValue;
in

fetchBytes url 6

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
