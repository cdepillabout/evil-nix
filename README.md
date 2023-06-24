# evil-nix

This is a Nix library that allows you to download files from the internet
without needing to provide an output hash.  It even works in Nix's `pure-eval`
mode.

This library relies on Nix's support for SHA1, an unsafe hash function.  It
utilizes known SHA1 hash collisions in order to sneak single bits of data out
of fixed-output derivations.

This library is comically inefficient, and should never be used in any actual
codebase.  But it is a fun trick!

## Usage

#### blah

mention it works in both restricted eval and pure eval modes!

nix build -L --restrict-eval && cat ./result && rm ./result

and

nix build -L --pure-eval && cat ./result && rm ./result

command for deleting everything that has been downloaded:
rm -rf ./result;
shopt -s nullglob;
nix-store --delete /nix/store/*-bitvalue-* /nix/store/*BitNum-* /nix/store/*-fetchFileSize* /nix/store/*-fetchByte*
