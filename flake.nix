{
  description = "FastAPI webhook listener that rebuilds a Hugo site on git push";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in
  {
    packages.${system}.default = pkgs.python3Packages.buildPythonApplication {
      pname = "blog-builder";
      version = "0.1.0";
      src = ./.;
      pyproject = true;

      propagatedBuildInputs = with pkgs.python3Packages; [
        fastapi
        gitpython
        uvicorn
      ];

      nativeBuildInputs = with pkgs.python3Packages; [
        setuptools
      ];
    };
    nixosModules.default = { config, lib, pkgs, ... }:
    let
      cfg = config.services.blog-builder;
    in
    {
      options.services.blog-builder = {
        enable = lib.mkEnableOption "FastAPI webhook listener for Hugo builds";
        port = lib.mkOption {
          type = lib.types.port;
          default = 8882;
          description = "Internal port on which to serve the FastAPI webhook.";
        };
        publicPort = lib.mkOption {
          type = lib.types.port;
          default = 80;
          description = "Public HTTP port served by Nginx.";
        };
        domain = lib.mkOption {
          type = lib.types.str;
          default = "localhost";
          description = "Domain or hostname served by Nginx.";
        };
        user = lib.mkOption {
          type = lib.types.str;
          default = "blogbuilder";
          description = "User to run the service as.";
        };
        group = lib.mkOption {
          type = lib.types.str;
          default = "blogbuilder";
          description = "Group to run the service as.";
        };
        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/var/lib/blog-builder";
          description = "Path to store the site configuration";
        };
      };
      config = lib.mkIf cfg.enable {
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = "${cfg.group}";
          description = "Service user from blog-builder";
        };
        users.groups.${cfg.group} = {};
        systemd.services.blog-builder ={
          description = "Python blog builder";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          path = with pkgs; [ hugo git ];
          preStart = ''
            cp -r ${self}/conf ${cfg.dataDir}
            chmod 755 ${cfg.dataDir}/conf
            chmod 644 ${cfg.dataDir}/conf/*
          '';
          serviceConfig = {
            ExecStart = "${self.packages.${system}.default}/bin/blog-builder";
            User = "${cfg.user}";
            Group = "${cfg.group}";
            Restart = "always";
            StateDirectory = "blog-builder";
            StateDirectoryMode = "0755";
            WorkingDirectory = "${cfg.dataDir}";
            Environment = [
              "WORKING_DIR=${cfg.dataDir}"
            ];
          };
        };
        services.nginx = {
          enable = true;
          virtualHosts.${cfg.domain} = {
            root = "${cfg.dataDir}/site/public";
            extraConfig = ''
              absolute_redirect off;
            '';
            listen = [{
              addr = "127.0.0.1";
              port = cfg.publicPort;
            }];
            locations."/" = {
              tryFiles = "$uri $uri/ index.html";
            };
            locations."~* \.(css|js|png|jpg|jpeg|gif|svg|ico|webp|ttf|woff2?)$" = {
              tryFiles = "$uri =404";
            };
          };
        };
        networking.firewall.allowedTCPPorts = [ cfg.publicPort ];
      };
    };
  };
}
