{
  description = "Nix library to allow downloading from the internet without using FODs";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in
    {
      overlay = final: prev: {
        evilDownloadUrl = final.callPackage ./evil {};

        evilExample =
          let
            url = "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/b64fa0c2e4fba7615221b633dce5ac30d9f26929/hello-world.txt";
          in
          final.evilDownloadUrl url;
      };

      evilDownloadUrl = forAllSystems (system: nixpkgsFor.${system}.evilDownloadUrl);

      packages = forAllSystems (system: { inherit (nixpkgsFor.${system}) evilExample; });

      defaultPackage = forAllSystems (system: self.packages.${system}.evilExample);
    };
}
