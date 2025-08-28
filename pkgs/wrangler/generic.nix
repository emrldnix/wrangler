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
  pnpm_9,
  autoPatchelfHook,
  llvmPackages,
  musl,
  xorg,
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

  majorVersion = lib.versions.major version;
  majMinVersion = lib.versions.majorMinor version;

  versionAtLeastFour = lib.versionAtLeast majorVersion "4";

  pname = "wrangler";

  src = fetchFromGitHub {
    owner = "cloudflare";
    repo = "workers-sdk";
    inherit tag hash;
  };

  pnpmDeps =
    (pnpm_9.fetchDeps {
      inherit pname version src;
      hash = pnpmDepsHash;

      fetcherVersion = 2;
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

  buildInputs = [
    llvmPackages.libcxx
    llvmPackages.libunwind
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux) [
    musl
    xorg.libX11
  ];

  nativeBuildInputs = [
    makeWrapper
    nodejs
    pnpm_9.configHook
    jq
    moreutils
  ]
  ++ lib.optionals (stdenv.hostPlatform.isLinux) [
    autoPatchelfHook
  ];

  # Credits to @ezrizhu
  postBuild = ''
    ${lib.optionalString versionAtLeastFour "mv packages/vitest-pool-workers packages/~vitest-pool-workers"}
    NODE_ENV="production" pnpm --filter workers-shared run build
    NODE_ENV="production" pnpm --filter miniflare run build
    NODE_ENV="production" pnpm --filter wrangler run build
  '';

  # I'm sure this is suboptimal but it seems to work. Points:
  # - when build is run in the original repo, no specific executable seems to be generated; you run the resulting build with pnpm run start
  # - this means we need to add a dedicated script - perhaps it is possible to create this from the workers-sdk dir, but I don't know how to do this
  # - the build process builds a version of miniflare which is used by wrangler; for this reason, the miniflare package is copied also
  # - pnpm stores all content in the top-level node_modules directory, but it is linked to from a node_modules directory inside wrangler
  # - as they are linked via symlinks, the relative location of them on the filesystem should be maintained
  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib $out/lib/packages/wrangler
    ${lib.optionalString versionAtLeastFour "mv packages/~vitest-pool-workers packages/vitest-pool-workers"}
    cp -r fixtures $out/lib
    cp -r packages $out/lib
    cp -r node_modules $out/lib
    cp -r tools $out/lib/tools

    # jsrpc is vendored from 4.31
    ${lib.optionalString (lib.versionAtLeast majMinVersion "4.31") "cp -r vendor $out/lib"}

    rm -rf node_modules/typescript node_modules/eslint node_modules/prettier node_modules/bin node_modules/.bin node_modules/**/bin node_modules/**/.bin
    rm -rf $out/lib/**/bin $out/lib/**/.bin
    NODE_PATH_ARRAY=( "$out/lib/node_modules" "$out/lib/packages/wrangler/node_modules" )
    makeWrapper ${lib.getExe nodejs} $out/bin/wrangler \
      --inherit-argv0 \
      --prefix-each NODE_PATH : "$${NODE_PATH_ARRAY[@]}" \
      --add-flags $out/lib/packages/wrangler/bin/wrangler.js \
      --set-default SSL_CERT_FILE "${cacert}/etc/ssl/certs/ca-bundle.crt" # https://github.com/cloudflare/workers-sdk/issues/3264

    runHook postInstall
  '';
}
