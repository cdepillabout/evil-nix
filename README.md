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

This library provides an `evilDownloadUrl` function, which downloads the file
of the passed URL.

> **WARNING**: This `evilDownloadUrl` function is terribly inefficient.  It may
> use up all your disk space, and DOS the site you're trying to download from.
> I don't recommend using it to download a file larger than 50 bytes or so
> (unless you really know what you're doing).  The reason for this inefficiency
> is explained in the next section.

You can play around with this function in the Nix REPL:

```console
$ nix repl ./nix
nix-repl> :b evilDownloadUrl "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"

This derivation produced the following outputs:
  out -> /nix/store/jhyzz6l9ryjl1npdf4alqyi1fy2qx1f0-fetchBytes-6bba65f4567f4165109177a5dafd5972882643e15d454018586fed35b068acf5-12
```

And then you can confirm that this file actually contains the contents of the
URL:

```console
$ cat /nix/store/jhyzz6l9ryjl1npdf4alqyi1fy2qx1f0-fetchBytes-6bba65f4567f4165109177a5dafd5972882643e15d454018586fed35b068acf5-12
hello world
```

There is also a top-level `default.nix` that can be used to play around with
this function:

```console
$ nix-build --argstr url "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello.txt"
$ cat ./result
hello world
```

You can also use the [`flake.nix`](./flake.nix) file to play around with this.
First, edit `./flake.nix` and replace `url = "..."` with the URL you want to
download.  Then, build the default package in the flake:

```console
$ nix build
$ cat ./result
hello world
```

The neat (evil) thing about `evilDownloadUrl` is that it even works in Nix's
[`pure-eval`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-pure-eval)
mode.  In theory, `pure-eval` is supposed to require all downloaded files to
have a hash specified:

```console
$ nix build --pure-eval
$ cat ./result
hello world
```

### Extreme Inefficiency

Due to the way this hack works, `evilDownloadUrl` is extremely inefficient.
It does a request to the URL for every _bit_ (**!!**) of the file it is
trying to download.  For instance, if you were trying to download a
10 byte file, `evilDownloadUrl` would actually download the file _80_ times.

`evilDownloadUrl` also makes a lot of garbage in your Nix store.  Downloading a
50 byte file makes about 4MB of garbage in your Nix store.

It is also very slow.  Downloading a 50 byte file takes about 30 seconds on my
machine.

While this is a fun library, you should never use this in any actual codebase.

### Clean Up `/nix/store`

After playing around with `evilDownloadUrl`, you may want to clean up the
garbage in your Nix store.  While you should always be able to use
`nix-collect-garbage` to do a GC, you may want to specifically only delete
files created by `evilDownloadUrl`.

First, make sure you don't have the `result` output creating a GC root:

```console
$ rm ./result
```

Then, delete files created by `evilDownloadUrl`:

```console
$ shopt -s nullglob   # you may want to enable null globs in Bash to ignore globs that don't match
$ nix-store --delete /nix/store/*-bitvalue-* /nix/store/*BitNum-* /nix/store/*-fetchFileSize* /nix/store/*-fetchByte*
```

## How does this work?

### Intro to Nix concepts for the non-Nixer

### Technical Explanation

## Use Cases

## Does `evil-nix` pose a security-related problem to the Nix ecosystem?

No

## FAQ


### blah

mention it works in both restricted eval and pure eval modes!

nix build -L --restrict-eval && cat ./result && rm ./result

and

nix build -L --pure-eval && cat ./result && rm ./result

command for deleting everything that has been downloaded:
rm -rf ./result;
shopt -s nullglob;
nix-store --delete /nix/store/*-bitvalue-* /nix/store/*BitNum-* /nix/store/*-fetchFileSize* /nix/store/*-fetchByte*
