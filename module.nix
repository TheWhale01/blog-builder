{ config, pkgs, lib, ... }:
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
    };

    systemd.services.blog-builder = {
      description = "FastAPI webhook listener for Hugo blog rebuilds";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        User = cfg.user;
        WorkingDirectory = cfg.workingDir;
        ExecStart = "${pkgs.blog-builder}/bin/blog-builder";
        Restart = "on-failure";
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts.${cfg.domain} = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.publicPort;
        }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.publicPort ];
  };
}
