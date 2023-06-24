{...}:

# This file produces a full Nixpkgs, with the overlay containing
# `evilDownloadUrl` applied.
#
# This is convenient to use with `nix repl`:
#
# $ nix repl ./nix
# nix-repl>
#
# Within this nix-repl, you have access to `evilDownloadUrl`:
#
# nix-repl> evilDownloadUrl "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt";

let
  flake-lock = builtins.fromJSON (builtins.readFile ../flake.lock);

  nixpkgs-src = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${flake-lock.nodes.nixpkgs.locked.rev}.tar.gz";
    sha256 = flake-lock.nodes.nixpkgs.locked.narHash;
  };

  overlays = [
    (import ./overlay.nix)
  ];

  pkgs = import nixpkgs-src { inherit overlays; };

in

pkgs
