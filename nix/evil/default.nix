
{runCommand, callPackage, lib}:

url:

let
  # The total number of bits to use to represent a file size (in bytes).
  # This means that at maximum, if fileSizeTotalBits is 16, then you can only
  # download files less than 65kb (2 ^ 16).
  #
  # WARNING: While technically you should be able to bump this value in order
  # to download files larger than 65kb, this will likely fill up your Nix store,
  # use up all your RAM, DOS the host you're trying to download from, etc.
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
