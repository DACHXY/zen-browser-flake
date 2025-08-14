{
  description = "Zen Browser";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
      };
    in
    {
      packages."${system}" = rec {
        zen-browser = pkgs.callPackage ./nix/package.nix { inherit system; };
        default = zen-browser;
      };
      homeManagerModules."${system}" = rec {
        zen-browser = import ./nix/hm-module.nix self;
        default = zen-browser;
      };
    };
}
