
{ runCommand }:

# This builds a derivation that has multiple outputs, each with a different
# value, but the same SHA1 hash collision.
#
# This is taken from
# https://github.com/NixOS/nixpkgs/commit/ed8f3b5fa3cebfc3662ad5fff098567616220cf8.
# from @aszlig.

runCommand
  "sha1-collisions"
  {
    outputs = [ "out" "bitValue1Pdf" "bitValue0Pdf" ];
    # A base-64 encoded tarball that contains two PDF files, each with a
    # different value, but with the same SHA1 hash.
    base64 = ''
      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
      NC/4ct6rQkPkQHMcV/8XckU4UJCy+VeTA==
    '';
    passthru.sha1 = "d00bbe65d80f6d53d5c15da7c6b4f0a655c5a86a";
  }
  ''
    echo "$base64" | base64 -d | tar xj
    mv good.pdf "$bitValue1Pdf"
    mv bad.pdf "$bitValue0Pdf"
    touch "$out"
  ''
