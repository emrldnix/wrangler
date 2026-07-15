{
  description = "Wrangler, the CLI for Cloudflare Workers, packaged as a nix flake";

  inputs.nixpkgs.url = "https://channels.nixos.org/nixpkgs-unstable/nixexprs.tar.zst";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs (builtins.filter (x: x != "x86_64-darwin") lib.systems.flakeExposed);
    in
    rec {
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      packages = forAllSystems (system: rec {
        wrangler_4 = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/wrangler/4_x.nix { };

        wrangler = wrangler_4;
        default = wrangler;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nixfmt
              nodejs
              pnpm
            ];
          };
        }
      );

      checks = packages // devShells;
    };
}
