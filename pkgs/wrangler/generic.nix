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

  pname = "wrangler";

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "workers-sdk";
    inherit tag hash;
  };

  pnpm = pnpm_10.override {
    nodejs-slim = nodejs-slim_latest;
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

  extraDeps = [
    "unenv-preset"
    "workers-utils"
    "local-explorer-ui"
    "codemod"
    "cli-shared-helpers"
    "miniflare"
    "config"
    "deploy-helpers"
    "workers-auth"
    "autoconfig"
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
    mv packages/vitest-pool-workers packages/~vitest-pool-workers
    for pkg in ${toString extraDeps}; do
      NODE_ENV="production" pnpm --filter "$pkg" run build
    done
  '';

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
