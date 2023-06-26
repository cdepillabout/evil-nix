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

This library provides an `evilDownloadUrl` function, which takes a single URL
as an argument, and downloads the file.

> **WARNING**: `evilDownloadUrl` is terribly inefficient.  It may use up
> significant disk space, and DOS the site you're trying to download from. I
> don't recommend using it to download a file larger than 50 bytes or so
> (unless you really know what you're doing).  The reasons for this inefficiency
> are explained in the next section.
>
> This section uses an example file that is only a few bytes long, so in
> general it should be safe to test out and play around with.

You can play around with this function in the Nix REPL:

```console
$ nix repl ./nix
nix-repl> :b evilDownloadUrl "https://raw.githubusercontent.com/cdepillabout/small-example-text-files/177c95e490cf44bcc42860bf0652203d3dc87900/hello-world.txt"

This derivation produced the following outputs:
  out -> /nix/store/jhyzz6l9ryjl1npdf4alqyi1fy2qx1f0-fetchBytes-6bba65f4567f4165109177a5dafd5972882643e15d454018586fed35b068acf5-12
```

You can confirm that this file actually contains the contents of the URL:

```console
$ cat /nix/store/jhyzz6l9ryjl1npdf4alqyi1fy2qx1f0-fetchBytes-6bba65f4567f4165109177a5dafd5972882643e15d454018586fed35b068acf5-12
hello world
```

There is also a top-level [`default.nix`](./default.nix) file that can be used to play around with
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
have a hash specified, but `evilDownloadUrl` works around this _limitation_:

```console
$ nix build --pure-eval
$ cat ./result
hello world
```

### Extreme Inefficiency

Due to the way this hack works, `evilDownloadUrl` is extremely inefficient.
It performs one request to the URL for every _bit_ (**!!**) of the file it is
trying to download.  For instance, if you were trying to download a
10 byte file, `evilDownloadUrl` would make _80_ requests to the URL, and
download the file _80_ times.

`evilDownloadUrl` also makes a lot of garbage in your Nix store.  Downloading a
50 byte file creates about 4MB of garbage in your Nix store.  This scales
linearly. For example, a 100 byte would create about 8MB of garbage.

It is also very slow.  Downloading a 50 byte file takes about 30 seconds on my
machine.

While this is a fun library, you should never use this in any actual codebase.

### Clean Up `/nix/store`

After playing around with `evilDownloadUrl`, you may want to clean up the
garbage in your Nix store.  While you should always be able to use
`nix-collect-garbage` to clean up your Nix store, you may want to specifically
only delete files created by `evilDownloadUrl`.

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

The `evilDownloadUrl` function works by internally creating a fixed-output
derivation which outputs one of two known PDF files, both with the same SHA1 hash.
This fixed-output derivation is allowed to access the network, and outputs
one PDF file to represent a single `1` bit, and the other PDF file to represent a
single `0` bit.  This effectively leaks one bit of information from the
internet in a non-reproducible manner.

`evilDownloadUrl` combines many of these 1-bit-leaking fixed-output derivations
in order to download the entire specified file from the internet.

The next section is an introduction to Nix for a non-Nixer (or anyone that
needs a refresher), focusing on the concepts needed to explain how
`evilDownloadUrl` works. The section after is a technical explanation
of how `evilDownloadUrl` works.

### Intro to Nix concepts for the non-Nixer

This section introduces the Nix concepts required for understanding `evil-nix`.
It does this mostly by drawing comparisons to other build tools, including
Docker.  These will be rough comparisons, intending to give you an idea about
what is going on without having to dive head-first into the inner-workings of
Nix.

> While these explanations are intended to give you some idea of what is going
> on, they may not be 100% completely technically accurate.  If you're a
> long-time Nix user, you're recommended to just jump directly to the technical
> explanation in the following section.

The Nix ecosystem is comprised of [quite a few different things]():

-   Nix is a build tool and system daemon, somewhat similar to `docker build` and `dockerd`.

-   Nix is also a programming language, similar to the language used to write
    `Dockerfile`s (although Nix is more powerful and more composable)

-   There is a large set of packages defined using the Nix language, called
    [Nixpkgs](https://github.com/NixOS/nixpkgs).  Nixpkgs is somewhat similar
    to the Debian or Arch Linux package sets.  Although, because of Nix's
    programability and composability, Nixpkgs feels much more flexible than
    other Linux distro's package sets.

-   There is a Linux distribution called NixOS, which uses the Nix programming
    language to define system settings (for example, the contents of files in
    `/etc`), and uses packages from Nixpkgs.  NixOS feels like a cross between
    a normal Linux distribution and a tool like Ansible/Puppet/Chef.

In order to understand `evil-nix`, we only need to look at Nix
the-programming-language and Nix the-build-tool.

The Nix programming language has a concept of a _derivation_.  A derivation is
a recipe to build a software package.  It is roughly similar to a `Dockerfile`.
Let's look at a simple derivation:

```console
stdenv.mkDerivation {
  name = "hello-2.12.1";

  src = ./.;

  nativeBuildInputs = [ gcc make ];
}
```

This is a derivation to build the
[GNU Hello](https://www.gnu.org/software/hello/) program. It declares its name
and version (`name = "hello-2.12.1"`), and takes the input source code from the
current directory (`src = ./.`).  It declares two needed build tools, `gcc` and
`make`.

You may be wondering why there is no code explicitly calling `./configure &&
make && make install`.  The `mkDerivation` function has internal support for
checking if there is an Automake build system, and automatically runs these
commands for us.  Pretty convenient!  Nix of course allows you to specify any
arbitrary build commands you may want to run (similar to a `Dockerfile`), but in this
case it is not needed.

If this derivation is saved to a file in the current directory called
`hello.nix` (and the current directory also contains the source code for the
GNU Hello package), you should be able to build this derivation with a command
like the following:

> Note that this `./hello.nix` file is not a _real_ derivation, and you can't
> actually save it to disk and run it as-is.  It has been slightly modified to
> be easier to understand for people new to Nix.  Checkout one of the following
> tutorials an intro to writing real derivations:
>
> 1. [Your First Derivation](https://github.com/justinwoo/nix-shorts/blob/master/posts/your-first-derivation.md)
> 2. [Hacking Your First Package](https://nix-tutorial.gitlabpages.inria.fr/nix-tutorial/first-package.html)
> 3. [My first Nix derivation](https://www.adelbertc.com/first-nix-derivation/)

```console
$ nix-build ./hello.nix
```

This `nix-build` tool passes off the derivation to a system daemon.  The system
daemon starts up a sandbox using Linux namespaces and cgroups, and pulls in all
the declared build tools, system libraries, and source code.  In our case, the
only build tools that have been declared and available in the sandbox are `gcc`
and `make`.  The system daemon then runs the specified build steps in the
sandbox environment (which in our case are `./configure && make && make
install`).  After running a build, the derivation is responsible for
_outputting_ a file (or a directory containing multiple files).  The output
file is is known as the _output of the derivation_ (or just the "_output_").  The
output of a derivation is generally an ELF binary, HTML documentation, man
pages, etc.

The sandbox is a key element here. The Nix system daemon sandbox is very
similar to the Docker daemon sandbox. However, the Nix system daemon goes one
step further.  It doesn't even allow network access.  Since network access is
not allowed during builds, you can be reasonably sure that your derivation is
100% reproducible. Regardless of what computer you run it on, it should always
succeed or fail the same way.

At this point, you may have the question, "Well, that's good and all, but if I
don't have network access, how do I download the source code I need to build? I
don't want to always have to keep the source code I want to build in my current
directory!"

To solve this problem, Nix provides a special type of derivation, called a
_fixed-output derivation_.  Here's an example of a fixed-output derivation:

```console
fetchurl {
    url = "https://ftp.gnu.org/pub/gnu/hello/hello-2.12.1.tar.gz";
    sha256 = "sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=";
}
```

Fixed-output derivations are special in that they require the hash of the
_output_ of the derivation to be specified in advance (the `sha256 =` line above). In
exchange for specifying the hash, the Nix system daemon sandbox allows access
to the network.  The above derivation is allowed to use `curl` to download the
`hello-2.12.1.tar.gz` file, and set it as the _output_ of this fixed-output
derivation.  This `hello-2.12.1.tar.gz` file must have the SHA256 hash
`sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=`.

Since the output hash is known, we can expect full 100% reproducibility of this
derivation.  If the derivation doesn't produce an output that exactly matches
the hash, then the Nix system daemon will get angry and fail the build.

Just like non-fixed-output derivations, fixed-output derivations allow you to
specify any arbitrary build commands you want.  The above `fetchurl` function
is setup to use `curl`, but you could potentially write a similar function that
internally uses `wget` instead.  Or maybe a derivation that uses `ftp` to pull
a file from an FTP server.

You can see that the above derivation uses a SHA256 hash.  Nix supports a few
different hash types, including SHA1.  `evil-nix` exploits the fact that SHA1
has known hash collisions.

In practice, the Nix language makes it very easy to combine multiple
derivations together.  For instance, the following Nix code is a normal
derivation for GNU Hello, where the source code for GNU Hello is taken as the
_output_ of a fixed-output derivation:

```console
stdenv.mkDerivation {
  name = "hello-2.12.1";

  src = fetchurl {
    url = "https://ftp.gnu.org/pub/gnu/hello/hello-2.12.1.tar.gz";
    sha256 = "sha256-jZkUKv2SV28wsM18tCqNxoCZmLxdYH2Idh9RLibH2yA=";
  };

  nativeBuildInputs = [ gcc make ];
}
```

This ability to programmatically and easily combine different derivations makes
Nix quite useful!  (As an aside, both the `gcc` and `make` build inputs are
also just normal derivations, defined quite similarly to this GNU hello
derivation).

With this knowledge of normal _derivations_, _fixed-output derivations_, and
derivation _outputs_, you should be set to understand how `evil-nix` exploits
fixed-output derivations.

### Technical Explanation

The main trick in `evilDownloadUrl` is a fixed-output derivation that returns
one bit of (non-hashed) data from the internet.  This fixed-output derivation
works by first preparing two different output files.  Let's call these output files
`pdfA` and `pdfB`.

These are special PDF files that have the same SHA1 hash.  The hash of the
fixed-output derivation is set to this SHA1 hash.  This works because Nix still
supports fixed-output derivations using SHA1 hashes (in the name of backwards
compatibility).

This fixed-output derivation takes a URL and a bit index as input. It downloads
the input URL using `curl`, and inspects the bit at the given input index of
the file. If the bit is a `1`, the fixed-output derivation sets `pdfA` as the
output. If the bit is a `0`, it sets `pdfB` as the output.

This is the critical trick.  From an information-theoretic perspective, you
would expect that a fixed-output derivation is not able to realistically
produce any additional information that is not already accounted for in the
hash of the output.  However, by combining a fixed-output derivation and a hash
function with known collisions, it is possible to sneak out a single bit of data.

You can see what this fixed-output derivation looks like in the file
[`nix/evil/downloadBitNum.nix`](./nix/evil/downloadBitNum.nix).  This
derivation is referred to as `downloadBitNum` in the `evil-nix` codebase.

`downloadBitNum` is then wrapped with a simple (non-fixed-output) derivation
that inspects the output of `downloadBitNum`.  This simple derivation is
referred to as `fetchBit` in the codebase.

`fetchBit` inspects the output of `downloadBitNum` and sees whether it matches
`pdfA` or `pdfB`. If `pdfA` has been output, then `fetchBit` will create a
single output file with the contents of an ASCII `1` character.  If
`downloadBitNum` has output `pdfB`, then `fetchBit` will create a single output
file with the contents of an ASCII `0` character.

You can see what `fetchBit` looks like in the file
[`nix/evil/fetchBit.nix`](./nix/evil/fetchBit.nix).

`fetchBit` is then repeated 8 times, and the subsequent outputs combined to
form a full byte of the input URL.  This is done in the function `fetchByte`,
which is defined in [`nix/evil/fetchByte.nix`](./nix/evil/fetchByte.nix).

`fetchByte` is then repeated for each byte of the input file.  This is done in
the function `fetchBytes`, which is defined in
[`nix/evil/fetchBytes.nix`](./nix/evil/fetchBytes.nix).

`fetchBytes` outputs the full file we wanted to download from the input URL.

By utilizing fixed-output derivations with SHA1 collisions, we're able to
download all the individual bits of the input URL, and carefully reassemble
them to form the full file.

## Use Cases

Due to the extreme inefficiency of `evilDownloadUrl`, the main use-case is not
for Nix users, but actually for non-Nix users.

If you work in IT, I'm sure you have at least one coworker who is _waaaay_ too
into Nix.  They likely bring up Nix in every conversation about your project's
build system, CI, packaging, deployment, etc. You've probably heard them say
the word "hermetic" at least 5 times in the last week.

The main use-case of `evil-nix` is for you. Next time you hear your coworker
start to bring up Nix, hit them with "Eh, I heard Nix isn't that great.  You
can trivially download unhashed files.  Talk about lack of _reproducibility_,
haha"

Your coworker will likely start sputtering about sandboxes, unsafe hash
functions, build purity, composability, etc.  However, you can safely ignore
them, and rest assured in your current build system's mishmash of Makefiles,
Bash scripts, YAML files, and containers.

If your coworker still won't take the hint, suggest to them that they should learn a
_real_ build tool, like _Docker_.

## FAQ

1.  _Does `evil-nix` pose a security-related problem to the Nix ecosystem?_

    No.

    `evil-nix` gives you a way to write derivations that are potentially less
    reproducible, even in `pure-eval` mode (where you would expect that
    all downloaded files must be hashed).

    However, reproducibility of Nix builds can be thwarted in many other ways
    than just `evil-nix`, so the techniques from `evil-nix` are not something
    to worry about in practice.

    (You should of course be careful with evaluating any untrusted Nix code from
    the internet, _very_ careful with building any untrusted Nix derivations
    from the internet, and **_extremely_** careful with running any untrusted
    binaries from the internet.)

1.  _Does this work with MD5 hashes instead of SHA1 hashes?_

    Yes.

    Nix currently supports many different hash types for fixed-output
    derivations, including insecure hash functions like MD5 and SHA1.

    The technique used by `evil-nix` relies on SHA1 collisions, but MD5
    collisions could be used instead.

1.  _Does `evilDownloadUrl` require [import from derivation](https://blog.hercules-ci.com/2019/08/30/native-support-for-import-for-derivation/) (IFD)?_

    No.

    `evilDownloadUrl` does currently makes use of IFD in order to read the length
    of the file in bytes before downloading.  However, it would be trivial to have
    `evilDownloadUrl` also take the file length as an input.

    The end-user would have to specify the file length they want to download,
    but then `evilDownloadUrl` could work with the
    `--no-allow-import-from-derivation` option.

1.  _What is the difference between `evilDownloadUrl` and `builtins.fetchTarball`?_

    Nix provides a few built-in functions that enable you to download files
    from the internet without needing to specify a hash.  One example is
    `builtins.fetchTarball`.

    The difference between `builtins.fetchTarball` and `evilDownloadUrl` is
    that `evilDownloadUrl` works even in Nix's
    [pure-eval](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-pure-eval)
    mode.  If you try to use `builtins.fetchTarball` in pure-eval mode without
    specifying a hash, Nix will give you an error message.

1.  _Could Nix be fixed to stop `evilDownladUrl` from working?_

    Yes.

    If Nix removed support for MD5 and SHA1 hashes for fixed-output
    derivations, that would stop `evilDownloadUrl` from working.
    However, it appears that MD5 and SHA1 hashes are still supported
    in the name of
    [backwards compatibility](https://github.com/NixOS/nix/issues/802#issuecomment-559759865).

    Here are two potential changes that could be made to Nix that would stop
    `evilDownloadUrl` from working, but wouldn't completely break backwards
    compatibility:

    -   Disallow MD5 and SHA1 hashes for fixed-output derivations in pure-eval
        mode.

        If someone wanted to use a new version of Nix to evaluate old Nix code
        that contained MD5 or SHA1 hashes, they would have to turn off
        pure-eval mode.  This seems like it could be a reasonable trade-off,
        especially since pure-eval mode is a relatively recent addition to Nix.

    -   Completely disable MD5 and SHA1 support by default, and hide
        functionality behind a config option.

        If someone wanted to use a new version of Nix to evaluate old Nix code
        that contained MD5 of SHA1 hashes, they would have to explicitly turn on
        the option that enables support for these weaker hash functions.

    In practice, no recent Nix code uses MD5 or SHA1 hashes.  I don't think
    I've ever seen an MD5 or SHA1 hash in Nix code in the wild, at least in the
    last 5 years or so.

1.  _Can `evildDownloadUrl` return different data every time it is called with the same URL?_

    Imagine you have a URL like `http://example.com/random` that returns a
    random number everytime it is called:

    ```console
    $ curl http://example.com/random
    16
    $ curl http://example.com/random
    42
    ```

    Is it possible have `evilDownloadUrl` also return a completely random
    number everytime it is called with this same URL?

    Sort of.

    If you run a command like the following, `evilDownloadUrl` will
    return the contents of the URL, and all the build artifacts will
    be cached to the Nix store:

    ```console
    $ nix-build --argstr url "http://example.com/random"
    $ cat ./result
    16
    ```

    If you have a friend run the same command on their computer, they will get
    a different output (like `42`).

    However, if you build it again on your own machine, since all the build outputs
    are already in the Nix store, you will get the same output as previously:

    ```console
    $ nix-build --argstr url "http://example.com/random"
    $ cat ./result
    16
    ```

    One way to work around this is to collect the garbage in your Nix store,
    and re-run the build:

    ```console
    $ rm ./result
    $ nix-collect-garbage
    $ nix-build --argstr url "http://example.com/random"
    $ cat ./result
    77
    ```

    Alternatively, you could modify `evilDownloadUrl` to take an additional
    argument that allows you to "bust" the cache:

    ```console
    $ rm ./result
    $ nix-collect-garbage
    $ nix-build --argstr url "http://example.com/random" --argstr cache-buster foo
    $ cat ./result
    48
    $ nix-build --argstr url "http://example.com/random" --argstr cache-buster bar
    $ cat ./result
    3
    ```

    This cache-busting value would need to be supplied by the end user.

## Acknowledgements

As far as I can tell, [@aszlig](https://github.com/aszlig) came up with the
idea of using fixed-output derivations with hash collisions in order to
impurely check whether or not given URLs can be downloaded.  The first
implementation was in
[this commit](https://github.com/NixOS/nixpkgs/commit/28b289efa642261d7a5078cfa3a05ef1d6fa2826).

`evil-nix` generalizes this technique to allow downloading arbitrary bits of
files from the internet.  It then generalizes the approach even more to allow
downloading full files from the internet, without needing to specify the hash
of the file.

Thanks to [@sternenseemann](https://github.com/sternenseemann) for originally
linking me to the above commit, and suggesting it as a potential approach to
[this issue](https://github.com/NixOS/nixpkgs/issues/223390).
