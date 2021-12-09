{ stdenv, buildPackages, fetchFromGitHub, lib }:

stdenv.mkDerivation {
  pname = "wasilibc";
  version = "unstable-2021-09-23";

  src = buildPackages.fetchFromGitHub {
    owner = "WebAssembly";
    repo = "wasi-libc";
    rev = "ad5133410f66b93a2381db5b542aad5e0964db96";
    hash = "sha256:146jamq2q24vxjfpcwlqj84wzc80cbpbg0ns2wimyvzbanah48j6";
    fetchSubmodules = true;
  };

  # clang-13: error: argument unused during compilation: '-rtlib=compiler-rt' [-Werror,-Wunused-command-line-argument]
  postPatch = ''
    substituteInPlace Makefile \
      --replace "-Werror" ""
  '';

  makeFlags = [
    "WASM_CC=${stdenv.cc.targetPrefix}cc"
    "WASM_NM=${stdenv.cc.targetPrefix}nm"
    "WASM_AR=${stdenv.cc.targetPrefix}ar"
    "INSTALL_DIR=${placeholder "out"}"
  ];

  postInstall = ''
    mv $out/lib/*/* $out/lib
    ln -s $out/share/wasm32-wasi/undefined-symbols.txt $out/lib/wasi.imports
  '';

  meta = with lib; {
    description = "WASI libc implementation for WebAssembly";
    homepage = "https://wasi.dev";
    platforms = platforms.wasi;
    maintainers = with maintainers; [ matthewbauer ];
    license = with licenses; [ asl20 mit llvm-exception ];
  };
}
