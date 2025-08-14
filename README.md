# Zen Browser

This is a flake for the Zen browser.

Just add it to your NixOS `flake.nix` or home-manager:

```nix
inputs = {
  zen-browser.url = "github:DACHXY/zen-browser-flake";

  # Other input
  ...
}
```

## Home Manager Option Example

```nix
let
  # user chrome plugin
  zenNebula = pkgs.fetchFromGitHub {
    owner = "justadumbprsn";
    repo = "zen-nebula";
    rev = "main";
    sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };
in
{
  programs.zen-browser = {
    enable = true;
    profiles = {
      "Default Profile" = {
        default = true;
        name = "Default";
        settings = {
          "zen.view.compact.should-enable-at-startup" = true;
          "zen.widget.linux.transparency" = true;
          "zen.view.compact.show-sidebar-and-toolbar-on-hover" = false;

          "app.update.auto" = false;
          "app.normandy.first_run" = false;
          "browser.aboutConfig.showWarning" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.shell.didSkipDefaultBrowserCheckOnFirstRun" = true;
          "browser.tabs.allow_transparent_browser" = true;
          "browser.urlbar.placeholderName" = "Google";
          "browser.urlbar.placeholderName.private" = "DuckDuckGo";
          "middlemouse.paste" = false;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
          "font.name.monospace.x-western" = "CaskaydiaCove Nerd Font Mono";
        };
        ensureCACertifications = [
          ../path/to/your/ca.crt
        ];
        chrome = zenNebula;
      };
    };
  };
}

```

## Packages

> NOTE: If `programs.zen-browser.enable` is set to `true`, the following is not required.

Then in the `configuration.nix` in the `environment.systemPackages`
or `home.packages` add:

```nix
inputs.zen-browser.packages."${system}".default
```

## 1Password

Zen has to be manually added to the list of browsers that 1Password will communicate with. See [this wiki article](https://nixos.wiki/wiki/1Password) for more information. To enable 1Password integration, you need to add the line `.zen-wrapped` to the file `/etc/1password/custom_allowed_browsers`.
