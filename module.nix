{ self, system, config, lib, pkgs, ... }:
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

    workingDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/blog-builder";
      description = "Working directory containing the cloned repo and generated site.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "blogbuilder";
      description = "User to run the service as.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.${cfg.user} = {
      isSystemUser = true;
      home = cfg.workingDir;
      createHome = true;
      group = cfg.user;
    };

    systemd.services.blog-builder = {
      description = "FastAPI webhook listener for Hugo blog rebuilds";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = cfg.workingDir;
        ExecStartPre = pkgs.writeShellScriptBin "blog-builder-pre-start" ''
          #!${pkgs.bash}/bin/bash

          mkdir -p ${cfg.workingDir}/public
          touch ${cfg.workingDir}/public/index.html
        '';
        ExecStart = "${self.packages.${system}.blog-builder}/bin/blog-builder";
        Restart = "on-failure";
        Environment = [
          "WORKING_DIR=${cfg.workingDir}"
          "PATH=${pkgs.hugo}/bin:/run/current-system/sw/bin:/usr/bin"
        ];
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        root = "${cfg.workingDir}/site/public";
        listen = [{
          addr = "127.0.0.1";
          port = cfg.publicPort;
        }];
        locations."/" = {
          try_files = "/index.html =404";
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.publicPort ];
  };
}
