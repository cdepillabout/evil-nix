
# This is just a simple Nixpkgs overlay that adds the evilDownloadUrl function
# for "purely" downloading a given URL.

final: prev: {
  evilDownloadUrl = final.callPackage ./evil {};
}
