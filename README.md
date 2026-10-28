# Cloudflare Workers Wrangler SDK Flake

Packaged [Cloudflare Wrangler SDK](https://developers.cloudflare.com/workers/wrangler/) ([github repo](https://github.com/cloudflare/workers-sdk)) in a Nix flake.

## Why?

`wrangler` is [already bundled](https://search.nixos.org/packages?channel=unstable&show=wrangler&from=0&size=50&sort=relevance&type=packages&query=wrangler) with `nixpkgs`. You can use it as a standard `nix` package
as you would any other package...

```nix
  packages = with pkgs; [
    wrangler
    # any other packages you want...
  ];
```

However, the release cadence of `wrangler` is high - typically releasing a new
version every week - and it is not really possible for `nixpkgs` to keep up
with this. Hence, the version of `wrangler` available in `nixpkgs` will usually
be a little behind the latest version and if you're not using the `master` branch,
it could potentially be significantly behind the latest version.

We hope to provide an update to `wrangler` on the `nixpkgs` `master` branch
approximately every month or so.

If you want to use the most up to date version of `wrangler`, you can use this
flake which is updated more frequently - we will try to update this within a
few days of the latest `wrangler` release.

## Usage

Get the recent release of wrangler in your flake inputs:

```nix
{
  inputs.wrangler = {
    url = "github:emrldnix/wrangler";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, wrangler }: {
    # Use wrangler in your outputs
  };
}
```

A more specific example of how this can be used in a workers project is
provided in [examples/hello-world](examples/hello-world).

### Using the NAR Cache

If you don't want to build the latest release of `wrangler` every time, you can skip the builds and download directly from my NAR cache.

```nix
{
  inputs.wrangler = {
    url = "github:emrldnix/wrangler";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, wrangler }: {
    nix.settings = {
      substituters = [ "https://cache.ryand.ca" ];
      trusted-public-keys = [ "ryandcache:H6aJbZCm8sAoMXCB9XbLAJb/ZamM6AY5Ns/QYGimOek=" ];
    };

    # Use wrangler in your outputs
  };
}
```

## Maintainers

- [dezren39](https://github.com/dezren39)
- [seanrmurphy](https://github.com/seanrmurphy)
- [ryand56](https://github.com/ryand56)
- [lemmih](https://github.com/lemmih)
