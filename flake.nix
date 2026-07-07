{
  description = "Wrangler, the CLI for Cloudflare Workers, packaged as a nix flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
        ];

        perSystem =
          {
            pkgs,
            ...
          }:
          rec {
            formatter = pkgs.nixfmt;

            packages = rec {
              wrangler_4 = pkgs.callPackage ./pkgs/wrangler/4_x.nix { };

              wrangler = wrangler_4;
              default = wrangler;
            };

            devShells = {
              default = pkgs.mkShell {
                packages = [
                  pkgs.nixfmt
                  pkgs.nodejs
                  pkgs.pnpm
                ];
              };
            };

            checks = packages // devShells;
          };
      }
    );
}
