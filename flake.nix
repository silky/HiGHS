{
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
  };
  outputs = { nixpkgs, flake-utils, ... }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs {
        inherit system;
      };

      version = with pkgs.lib;
        # Read the version. Note: We assume the version numbers are in
        # order in the file; i.e. Major, Minor, Patch.
        let f = builtins.readFile ./Version.txt;
        l = strings.splitString "\n" f;
        # Drop the last term; it just says if it's alpha or not.
        t = lists.take 3 l;
        # Get the numbers on the other side of the equals
        vs = lists.forEach t (v: lists.drop 1 (strings.splitString "=" v));
        # That's it!
        in concatStrings (intersperse "." (lists.flatten vs));

      highspyViaPythonPackage = pkgs.python3Packages.buildPythonPackage {
        inherit version;
        pname = "highspy";
        src = pkgs.lib.cleanSource ./.;
        format = "pyproject";
        dontUseCmakeConfigure = true;
        nativeBuildInputs = with pkgs.python3Packages; [
          pkgs.python3Packages.numpy
          pathspec
          pybind11
          pyproject-metadata
          scikit-build-core
          pkgs.cmake
          pkgs.ninja
        ];
        buildInputs = [
          pkgs.zlib
        ];
      };

      highspyViaCmake = with pkgs; stdenv.mkDerivation {
          pname = "highspy";

          inherit version;

          cmakeFlags = [
            "-DFAST_BUILD=ON"
            "-DPYTHON_BUILD_SETUP=ON"
          ];

          src = pkgs.lib.cleanSource ./.;

          buildInputs = with pkgs; [
            cmake
            clang
            (python3.withPackages (ps: with ps; [
              ps.pybind11
            ]))
            zlib
            ninja
          ];

          # mesonFlags = [
          #   "-Dwith_pybind11=true"
          # ];
          # nativeBuildInputs = [
          #   meson
          # ];

          postInstall = ''
            mkdir -p $out/${python3.sitePackages}
            ln -s $out/highspy $out/${python3.sitePackages}/highspy
          '';
        };

      highspyViaMeson = with pkgs; stdenv.mkDerivation {
          pname = "highspy";

          inherit version;

          src = pkgs.lib.cleanSource ./.;

          buildInputs = with pkgs; [
            (python3.withPackages (ps: with ps; [
              ps.pybind11
            ]))
            zlib
            meson
            ninja
          ];

          mesonFlags = [
            "-Dwith_pybind11=true"
            "-Dfast_build=true"
          ];
        };

      highspyModule = highspyViaPythonPackage;
      # highspyModule = pkgs.python3Packages.toPythonModule highspyViaMeson;
      # highspyModule = pkgs.python3Packages.toPythonModule highspyViaCmake;
    in rec {
      # defaultApp = flake-utils.lib.mkApp {
      #   drv = highs;
      # };
      defaultPackage = highspyModule;
      devShell = pkgs.mkShell {
        buildInputs = [
          (pkgs.python3.withPackages (ps: [ highspyModule ]))
        ];
      };
    }
  );
}

