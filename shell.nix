{ pkgs ? import <nixpkgs> {}, ... }:

pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    python3
    python3Packages.pip
    python3Packages.pkgs.virtualenv
    hugo
    nginx
    git
  ];
}
