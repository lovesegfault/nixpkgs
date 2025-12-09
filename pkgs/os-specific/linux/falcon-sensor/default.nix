{
  lib,
  stdenv,
  requireFile,
  kernel,
  kernelModuleMakeFlags,
  cpio,
  rpm,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "falcon-sensor-module";
  # Version format: sensor-version-kernel-version
  version = "7.18.0-17106-${kernel.version}";

  src = requireFile {
    name = "falcon-sensor-7.18.0-17106.el9.x86_64.rpm";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
    message = ''
      CrowdStrike Falcon sensor requires a valid subscription.

      1. Log in to the CrowdStrike Falcon Console:
         https://falcon.crowdstrike.com/hosts/sensor-downloads

      2. Download the RHEL/CentOS/Oracle 9 sensor package

      3. Add the package to the Nix store:
         nix-prefetch-url file://$PWD/falcon-sensor-7.18.0-17106.el9.x86_64.rpm

      Note: The version and hash in this file may need to be updated
      to match the version you download.
    '';
  };

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    cpio
    rpm
  ];

  hardeningDisable = [
    "pic"
    "format"
  ];

  sourceRoot = ".";

  unpackPhase = ''
    runHook preUnpack

    rpm2cpio $src | cpio -idmv
    sourceRoot="opt/CrowdStrike"

    runHook postUnpack
  '';

  # CrowdStrike may ship:
  # 1. Prebuilt kernel modules (.ko files)
  # 2. DKMS source for building against current kernel
  #
  # This package assumes DKMS source is available.
  # If only prebuilt modules exist, adjust installPhase to copy .ko directly.

  makeFlags = kernelModuleMakeFlags ++ [
    "KVER=${kernel.modDirVersion}"
    "KDIR=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
  ];

  buildPhase = ''
    runHook preBuild

    # Navigate to kernel module source (path may vary by version)
    # Typical locations:
    #   - opt/CrowdStrike/falcon-sensor-dkms/
    #   - usr/src/falcon-*
    if [ -d "usr/src" ]; then
      cd usr/src/falcon-*
    elif [ -d "opt/CrowdStrike/falcon-sensor-dkms" ]; then
      cd opt/CrowdStrike/falcon-sensor-dkms
    else
      echo "Could not find kernel module source. Contents:"
      find . -name "*.c" -o -name "Makefile" | head -20
      echo "Please adjust the buildPhase in this package."
      exit 1
    fi

    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build \
      M=$PWD \
      $makeFlags \
      modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install kernel module
    install -Dm644 falcon-sensor.ko \
      $out/lib/modules/${kernel.modDirVersion}/extra/falcon-sensor.ko

    runHook postInstall
  '';

  enableParallelBuilding = true;

  meta = {
    description = "CrowdStrike Falcon sensor kernel module for endpoint detection and response";
    homepage = "https://www.crowdstrike.com/";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [ lovesegfault ];
    platforms = [ "x86_64-linux" ];
    # Cannot be built by Hydra due to requireFile
    hydraPlatforms = [ ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
