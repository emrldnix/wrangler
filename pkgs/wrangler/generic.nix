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
  nodejs,
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

  pnpm = pnpm_10;

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
    inherit (nodejs.meta) platforms;
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

  env = lib.optionalAttrs stdenv.hostPlatform.isDarwin {
    NODE_OPTIONS = "--max-old-space-size=4096";
  };

  buildInputs = [
    llvmPackages.libcxx
    llvmPackages.libunwind
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    musl
    libx11
  ];

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm
    pnpmConfigHook
    jq
    moreutils
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  postBuild = ''
    NODE_ENV="production" pnpm --filter wrangler... run build
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,lib}
    pnpm config set --location=project injectWorkspacePackages true
    pnpm --filter=wrangler --prod deploy $out/lib

    makeWrapper ${lib.getExe nodejs} $out/bin/wrangler \
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
