{
  description = "Nix library to allow downloading files from the internet without using FODs";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });
    in
    {
      overlay = final: prev:
        import ./nix/overlay.nix final prev //
        {
          evilExample =
            let
              # This is a very short 5-byte example file.
              # url = "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello.txt";

              # This is a short 12-byte example file.
              url = "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt";

              # This is a longer 52-byte example file.
              # url = "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/short-sentence.txt";
            in
            final.evilDownloadUrl url;
        };

      evilDownloadUrl = forAllSystems (system: nixpkgsFor.${system}.evilDownloadUrl);

      packages = forAllSystems (system: { inherit (nixpkgsFor.${system}) evilExample; });

      defaultPackage = forAllSystems (system: self.packages.${system}.evilExample);
    };
}
