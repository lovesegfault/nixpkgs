{ stdenv
, lib
, fetchFromGitHub
, python2
}:
stdenv.mkDerivation rec {
  name = "klipper";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "KevinOConnor";
    repo = "klipper";
    rev = "v${version}";
    sha256 = "1ijy2ij9yii5hms10914i614wkjpsy0k4rbgnm6l594gphivdfm7";
  } + "/klippy";

  # there is currently an attempt at moving it to Python 3, but it will remain
  # Python 2 for the foreseeable future.
  # c.f. https://github.com/KevinOConnor/klipper/pull/3278
  nativeBuildInputs = [ (python2.withPackages (p: with p; [ cffi pyserial greenlet jinja2 ])) ];

  # we need to run this to prebuild the chelper.
  postBuild = "python2 ./chelper/__init__.py";

  # we need everything to live in the same directory because the code in
  # klippy.py (the program's entry point) relies on the working dir to find its
  # modules.
  installPhase = ''
    mkdir -p $out/lib
    cp -r ./* $out/lib

    chmod 755 $out/lib/klippy.py
  '';

  postFixup = ''
    patchShebangs $out/lib/console.py
    patchShebangs $out/lib/klippy.py
    patchShebangs $out/lib/parsedump.py
  '';

  meta = with lib; {
    description = "The Klipper 3D printer firmware";
    homepage = "https://github.com/KevinOConnor/klipper";
    maintainers = with maintainers; [ lovesegfault ];
    platforms = platforms.linux;
    license = licenses.gpl3;
  };
}
