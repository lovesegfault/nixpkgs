{
  lib,
  stdenvNoCC,
  requireFile,
  autoPatchelfHook,
  makeWrapper,
  cpio,
  rpm,
  glibc,
  openssl,
  zlib,
  libnl,
  systemd,
  curl,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "falcon-sensor";
  version = "7.18.0-17106";

  src = requireFile {
    name = "falcon-sensor-${finalAttrs.version}.el9.x86_64.rpm";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    message = ''
      CrowdStrike Falcon sensor requires a valid subscription.

      1. Log in to the CrowdStrike Falcon Console:
         https://falcon.crowdstrike.com/hosts/sensor-downloads

      2. Download the RHEL/CentOS/Oracle 9 sensor package

      3. Add the package to the Nix store:
         nix-prefetch-url file://$PWD/falcon-sensor-${finalAttrs.version}.el9.x86_64.rpm

      Note: The version and hash in this file may need to be updated
      to match the version you download.
    '';
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    cpio
    rpm
  ];

  buildInputs = [
    glibc
    openssl
    zlib
    libnl
    systemd
    curl
  ];

  # Some libraries may be optional or bundled
  autoPatchelfIgnoreMissingDeps = [
    "libcurl-nss.so.4"
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    runHook preUnpack
    rpm2cpio $src | cpio -idmv
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,opt,lib/systemd/system}

    # Copy CrowdStrike directory
    cp -a opt/CrowdStrike $out/opt/

    # Create wrapper for falconctl
    if [ -f $out/opt/CrowdStrike/falconctl ]; then
      makeWrapper $out/opt/CrowdStrike/falconctl $out/bin/falconctl \
        --prefix PATH : $out/opt/CrowdStrike
    fi

    # Create wrapper for the daemon (may be named differently)
    for daemon in falcond falcon-sensor falcon-sensor-daemon; do
      if [ -f "$out/opt/CrowdStrike/$daemon" ]; then
        makeWrapper "$out/opt/CrowdStrike/$daemon" "$out/bin/$daemon" \
          --prefix PATH : $out/opt/CrowdStrike
      fi
    done

    runHook postInstall
  '';

  dontStrip = true;

  meta = {
    description = "CrowdStrike Falcon endpoint protection sensor";
    longDescription = ''
      CrowdStrike Falcon is an endpoint detection and response (EDR) platform.
      This package provides the userspace sensor daemon and configuration utility.

      Note: This package requires a valid CrowdStrike subscription and Customer ID (CID)
      for activation. For full functionality, also install the falcon-sensor kernel module
      via boot.extraModulePackages.
    '';
    homepage = "https://www.crowdstrike.com/";
    license = lib.licenses.unfree;
    mainProgram = "falconctl";
    maintainers = with lib.maintainers; [ lovesegfault ];
    platforms = [ "x86_64-linux" ];
    hydraPlatforms = [ ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
