{
  lib,
  buildBazelPackage,
  fetchFromGitHub,
  callPackage,
  fetchpatch,
}:
buildBazelPackage rec {
  pname = "workerd";
  version = "1.20250608.0";
  bazel = callPackage ../bazel_8/package.nix { };

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "workerd";
    tag = "v${version}";
    hash = "sha256-DpE1CYEIxRwKl9KbEBC0oA1rIXcceVb32ElVQNxkC18=";
  };

  patches = [
    ./system-packages.patch
  ];

  dontAddBazelOpts = true;
  bazelFlags = [
    "--config"
    "thin-lto"

    "--linkopt"
    "-lc++"

    "--linkopt"
    "-lm"

    "--host_linkopt"
    "-lc++"

    "--host_linkopt"
    "-lm"
  ];
  bazelTargets = [ "server:workerd" ];

  fetchAttrs = {
    hash = lib.fakeHash;
  };
  buildAttrs = { };
}
