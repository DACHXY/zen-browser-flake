self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mkEnableOption
    mkIf
    types
    literalExpression
    concatStringsSep
    mapAttrs'
    mapAttrsToList
    nameValuePair
    ;

  inherit (builtins) toJSON toString;

  homeDir = config.home.homeDirectory;
  zenConfDir = "${homeDir}/.zen";

  cfg = config.programs.zen-browser;
  system = pkgs.stdenv.hostPlatform.system;

  package = self.packages.${system}.default;

  profileSetting =
    { name, ... }:
    {
      options = {
        default = (mkEnableOption "is default profile") // {
          default = false;
        };

        id = mkOption {
          type = types.int;
          default = 0;
          description = "Id of the profile, should be unique";
        };

        name = mkOption {
          type = types.str;
          default = name;
          description = ''profile name'';
        };

        settings = mkOption {
          type = types.attrs;
          default = { };
          description = ''user preference in "about:config"'';
          example = literalExpression ''
            {
              "browser.startup.homepage" = "https://nixos.org";
              "browser.search.region" = "GB";
              "browser.search.isUS" = false;
              "distribution.searchplugins.defaultLocale" = "en-GB";
              "general.useragent.locale" = "en-GB";
              "browser.bookmarks.showMobileBookmarks" = true;
              "browser.newtabpage.pinned" = [{
                title = "NixOS";
                url = "https://nixos.org";
              }];
            }
          '';
        };

        ensureCACertifications = mkOption {
          type = with types; listOf path;
          default = [ ];
          description = ''
            Trust the providing CA.
            NOTE: 'osConfig.security.pki,caBundle' may not work.
            Consider provide a single root CA instead.
          '';
        };
      };
    };

  userJsFiles = mapAttrs' (
    name: value:
    nameValuePair "${zenConfDir}/${name}/user.js" {
      source = (
        pkgs.writeText "zen-browser-${name}-user.js" ''
          ${concatStringsSep "\n" (
            mapAttrsToList (sname: svalue: "user_pref(\"${sname}\", ${toJSON svalue})") value
          )}
        ''
      );
    }
  ) cfg.profiles;

  profilesIni = {
    "${zenConfDir}/profiles.ini".source = pkgs.writeText "zen-browser-profiles.ini" ''
      ${concatStringsSep "\n\n" (
        mapAttrsToList (n: v: ''
          [Profile${toString v.id}]
          Name=${v.name}
          IsRelative=1
          Path=${n}
          Default=${toString (if v.default then 1 else 0)}
        '') cfg.profiles
      )}

      [General]
      StartWithLastProfile=1
      Version=2
    '';
  };

  caScript = pkgs.writeShellScript "zen-browser-ensure-ca.sh" ''
    certutil=${pkgs.nss.tools}/bin/certutil

    ${concatStringsSep "\n\n" (
      mapAttrsToList (
        name: value: # bash
        ''
          certs=(${toString (map (v: ''"${v}"'') value.ensureCACertifications)})
          PROFILE_DIR="${zenConfDir}/${name}"

          echo "Installing $PROFILE_DIR..."
          if [ -d "$PROFILE_DIR" ]; then

            # ==== Deleting CA ==== #
            EXISTING_CAS=()
            while IFS= read -r line; do
                # Skip header
                [[ "$line" =~ ^Certificate ]] && continue
                [[ "$line" =~ SSL,S/MIME,JAR/XPI ]] && continue
                [[ -z "$line" ]] && continue
                # Get nickname
                NICKNAME=$(awk '{NF--; print}' <<< "$line")
                EXISTING_CAS+=("$NICKNAME")
            done < <($certutil -L -d "sql:$PROFILE_DIR")

            echo existing ca:
            printf '%s\n' "''\${EXISTING_CAS[@]}"

            # Get All CA NAME
            TARGET_CAS=()
            for f in "''\${certs[@]}"; do
                if [ ! -f "$f" ]; then
                    echo "Warning: $f does not exist, skipping"
                    continue
                fi
                CN=$(${pkgs.openssl.bin}/bin/openssl x509 -noout -subject -in "$f" | sed -n 's/.*CN=\(.*\)/\1/p')
                TARGET_CAS+=("$CN")
            done

            for EXIST in "''\${EXISTING_CAS[@]}"; do
                if [[ ! " ''\${TARGET_CAS[*]} " =~ " $EXIST " ]]; then
                    echo "Deleting CA not in list: $EXIST"
                    $certutil -D -n "$EXIST" -d "sql:$PROFILE_DIR"
                fi
            done

            # ===== Adding CA ======
            for idx in "''\${!certs[@]}"; do
                CA_FILE="''\${certs[$idx]}"
                CN="''\${TARGET_CAS[$idx]}"
                if $certutil -L -d "sql:$PROFILE_DIR" | grep -q "$CN"; then
                    echo "CA already installed: $CN"
                    continue
                fi
                echo "Adding CA: $CN"
                $certutil -A -n "$CN" -t "CT,C," -d "sql:$PROFILE_DIR" -i "$CA_FILE"
            done
          else
            echo "${zenConfDir}/${name} not exist, skip"
          fi
        '') cfg.profiles
    )}
  '';
in
{
  options.programs.zen-browser = {
    enable = mkEnableOption "enable zen browser";
    profiles = mkOption {
      type = with types; attrsOf (submodule profileSetting);
      description = "profile settings";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      package
    ];

    home.file = userJsFiles // profilesIni;

    systemd.user.services = {
      zen-browser-ensure-ca = {
        Service = {
          ExecStart = "${caScript}";
        };
      };
    };

    home.activation.zen-browser-ensure-ca = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.systemd}/bin/systemctl --user restart zen-browser-ensure-ca.service
    '';
  };
}
