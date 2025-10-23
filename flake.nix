{
  description = "FastAPI webhook listener that rebuilds a Hugo site on git push";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      packages.${system}.blog-builder = pkgs.python3Packages.buildPythonPackage {
        pname = "blog-builder";
        version = "1.0.0";

        src = ./.;
        format = "other";

        propagatedBuildInputs = with pkgs.python3Packages; [
          fastapi
          gitpython
          uvicorn
          GitPython
        ];

        nativeBuildInputs = with pkgs; [
          hugo
          git
        ];

        installPhase = ''
          mkdir -p $out/bin
          cp webhook_listener.py $out/bin/webhook_listener.py
          chmod +x $out/bin/webhook_listener.py
          # Create launcher script
          cat > $out/bin/blog-builder <<EOF
          #!${pkgs.python3.interpreter}
          import sys, runpy; sys.argv = ['webhook_listener.py']; runpy.run_path('$out/bin/webhook_listener.py', run_name='__main__')
          EOF
          chmod +x $out/bin/blog-builder
        '';
      };

      defaultPackage.${system} = self.packages.${system}.blog-builder;
      nixosModules.blog-builder = { config, pkgs, lib, ... }: import ./module.nix {
        inherit self system config pkgs lib;
      };
   };
}
