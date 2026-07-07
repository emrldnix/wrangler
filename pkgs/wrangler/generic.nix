{
  version,
  tag ? "wrangler@${version}",
  hash,
  pnpmDepsHash,
}:

{
  lib,
  stdenv,
  cacert,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_9,
  pnpm_10,
  pnpmConfigHook,
  autoPatchelfHook,
  llvmPackages,
  musl,
  libx11,
  makeWrapper,
  nodejs-slim_latest,
  jq,
  moreutils,
}:
let
  # pnpm packageManager version in workers-sdk root package.json may not match nixpkgs
  # Credits to @ezrizhu
  preConfigure = ''
    jq 'del(.packageManager)' package.json | sponge package.json
  '';

  majorVersion = lib.versions.major version;

  versionAtLeastFour = lib.versionAtLeast majorVersion "4";
  versionThree = lib.versionOlder majorVersion "4";

  pname = "wrangler";

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "workers-sdk";
    inherit tag hash;
  };

  pnpmIdent = if lib.versionAtLeast lib.trivial.release "26.05" then "nodejs-slim" else "nodejs";

  pnpm = (if versionThree then pnpm_9 else pnpm_10).override {
    ${pnpmIdent} = nodejs-slim_latest;
  };

  pnpmDeps =
    (fetchPnpmDeps {
      inherit
        pname
        version
        src
        pnpm
        ;
      hash = pnpmDepsHash;
      fetcherVersion = 4;
    }).overrideAttrs
      (_: {
        preInstall = preConfigure;
      });

  extraDeps =
    lib.optionals versionAtLeastFour [
      "unenv-preset"
      "workers-utils"
      "local-explorer-ui"
      "codemod"
      "cli-shared-helpers"
    ]
    ++ lib.optionals versionThree [
      "workers-shared"
    ]
    ++ [
      "miniflare"
    ]
    ++ lib.optionals versionAtLeastFour [
      "config"
      "deploy-helpers"
      "workers-auth"
      "autoconfig"
    ]
    ++ [
      "wrangler"
    ];

  meta = {
    description = "Command-line interface for all things Cloudflare Workers";
    homepage = "https://github.com/cloudflare/workers-sdk#readme";
    license = with lib.licenses; [
      mit
      apsl20
    ];
    maintainers = with lib.maintainers; [
      seanrmurphy
      dezren39
      ryand56
    ];
    mainProgram = "wrangler";
    # Tunneling and other parts of wrangler, which require workerd won't run on
    # other systems where precompiled binaries are not provided, but most
    # commands are will still work everywhere.
    # Potential improvements: build workerd from source instead.
    inherit (nodejs-slim_latest.meta) platforms;
  };
in
stdenv.mkDerivation {
  inherit
    pname
    version

    src

    pnpmDeps
    preConfigure
    meta
    ;

  buildInputs = [
    llvmPackages.libcxx
    llvmPackages.libunwind
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux) [
    musl
    libx11
  ];

  nativeBuildInputs = [
    makeWrapper
    nodejs-slim_latest
    pnpm
    pnpmConfigHook
    jq
    moreutils
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux) [
    autoPatchelfHook
  ];

  # Credits to @ezrizhu
  postBuild = ''
    ${lib.optionalString versionAtLeastFour "mv packages/vitest-pool-workers packages/~vitest-pool-workers"}
    for pkg in ${toString extraDeps}; do
      NODE_ENV="production" pnpm --filter "$pkg" run build
    done
  '';

  # I'm sure this is suboptimal but it seems to work. Points:
  # - when build is run in the original repo, no specific executable seems to be generated; you run the resulting build with pnpm run start
  # - this means we need to add a dedicated script - perhaps it is possible to create this from the workers-sdk dir, but I don't know how to do this
  # - the build process builds a version of miniflare which is used by wrangler; for this reason, the miniflare package is copied also
  # - pnpm stores all content in the top-level node_modules directory, but it is linked to from a node_modules directory inside wrangler
  # - as they are linked via symlinks, the relative location of them on the filesystem should be maintained
  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib}
    pnpm config set --location=project injectWorkspacePackages true
    pnpm --filter=wrangler --prod deploy $out/lib

    makeWrapper ${lib.getExe nodejs-slim_latest} $out/bin/wrangler \
      --inherit-argv0 \
      --set NODE_PATH $out/lib/node_modules \
      --add-flags $out/lib/bin/wrangler.js \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" # https://github.com/cloudflare/workers-sdk/issues/3264

    runHook postInstall
  '';

  preFixup = ''
    # fixupPhase spends a lot of time trying to strip text files, which is especially slow on Darwin
    stripExclude+=("*.js" "*.ts" "*.map" "*.json" "*.md")
  '';
}
