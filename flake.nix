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
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { lib, ... }:
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ];

        perSystem =
          {
            self',
            pkgs,
            system,
            ...
          }:
          let
            inherit (pkgs) callPackage;
          in
          rec {
            formatter = pkgs.nixfmt-rfc-style;

            packages = rec {
              wrangler = callPackage ./pkgs/wrangler/4_x.nix { };
              wrangler_3 = callPackage ./pkgs/wrangler/3_x.nix { };

              workerd = callPackage ./pkgs/workerd/package.nix { };

              default = wrangler;
            };

            devShells = {
              default = pkgs.mkShell {
                packages = [
                  pkgs.nixfmt-rfc-style
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
