# evil-nix

mention it works in both restricted eval and pure eval modes!

nix build -L --restrict-eval && cat ./result && rm ./result

and

nix build -L --pure-eval && cat ./result && rm ./result

command for deleting everything that has been downloaded:
rm -rf ./result;
shopt -s nullglob;
nix-store --delete /nix/store/*-bitvalue-* /nix/store/*BitNum-* /nix/store/*-fetchFileSize* /nix/store/*-fetchByte*
