{ stdenv
, lib
, fetchFromGitHub
, python2
}: stdenv.mkDerivation rec {
  name = "klipper";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "KevinOConnor";
    repo = "klipper";
    rev = "v${version}";
    sha256 = "1ijy2ij9yii5hms10914i614wkjpsy0k4rbgnm6l594gphivdfm7";
  } + "/klippy";

  nativeBuildInputs = [ (python2.withPackages (p: with p; [ cffi pyserial greenlet jinja2 ])) ];

  # mark the main entrypoint as an executable
  postPatch = "chmod 755 ./klippy.py";

  # we need to run this to prebuild the chelper.
  postBuild = "python2 ./chelper/__init__.py";

  installPhase = ''
    mkdir -p $out/{bin,share}
    cp -r ./* $out/share
    ln -s $out/share/klippy.py $out/bin/klippy
  '';

  meta = with lib; {
    description = "The Klipper 3D printer firmware";
    homepage = "https://github.com/KevinOConnor/klipper";
    maintainers = with maintainers; [ lovesegfault ];
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}
