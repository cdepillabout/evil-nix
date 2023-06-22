
{ fetchByte
, runCommand
}:

# Fetch the given number of bytes from the specified URL.


# URL string to download.
# Example: "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"
url:

# Number of bytes from the URL to fetch.  This should normally be the file size
# of the file you want to download.
bytes:

let
  urlHash = builtins.hashString "sha256" url;

  # A list of derivations, each one outputting a single file the single given raw byte.
  l = builtins.genList (fetchByte url urlHash) bytes;
in
runCommand
  "fetchBytes-${urlHash}-${toString bytes}"
  {
    passAsFile = [ "allByteDrvs" ];
    allByteDrvs = l;
  }
  ''
    # Loop over all of the raw byte outputs, appending them into a single file.
    (tr ' ' '\n' < "$allByteDrvsPath" ; echo) | while read -r line ; do
      head -c1 "$line" >> $out
    done
  ''
