
{runCommand, callPackage, lib}:

# This function creates a derivaton that downloads and outputs the given URL,
# even without specifying a hash for the file. It does in a way that even
# works in pure-eval mode.
#
# Internally, it relies on Nix supporting FODs with SHA1 hashes, and utilizes
# known SHA1 hash collisions to sneak single bits of data from the internet out
# of FODs.


# URL to download.
# Example: "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
url:

let
  # The total number of bits to use to represent a file size (in bytes).
  # This means that at maximum, if fileSizeTotalBits is 16, then you can only
  # download files less than 65kb (2 ^ 16).
  #
  # WARNING: While technically you should be able to bump this value in order
  # to download files larger than 65kb, this will likely fill up your Nix store,
  # use up all your RAM, DOS the host you're trying to download from, etc.
  # You probably don't want to ever try to download files larger than even just
  # a few hundred bytes.
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

  fetchByte = callPackage ./fetchByte.nix {
    inherit fetchBit;
  };

  fetchBytes = callPackage ./fetchBytes.nix {
    inherit fetchByte;
  };

  fetchFileSize = callPackage ./fetchFileSize.nix {
    inherit fetchFileSizeBit fileSizeTotalBits;
  };

  fileSize = import (fetchFileSize url);
in
fetchBytes url fileSize
