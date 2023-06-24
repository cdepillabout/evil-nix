let
  nixpkgs = import ./nix {};
in

{ pkgs ? nixpkgs
, url ? "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
}:

pkgs.evilDownloadUrl url
