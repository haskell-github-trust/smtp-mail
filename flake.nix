{
  description = "smtp-mail";

  nixConfig = {
    extra-substituters = [ "https://cache.iog.io" ];
    extra-trusted-public-keys = [
      "hydra.iohk.io:f/Ea+s+dFdN+3Y/G+FDgSq+a5NEWhJGzdjvKNGv0/EQ="
    ];
  };

  inputs = {
    nixpkgs.follows = "haskell-nix/nixpkgs-unstable";
    haskell-nix.url = "github:input-output-hk/haskell.nix";
  };

  outputs = { self, nixpkgs, haskell-nix, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        inherit (haskell-nix) config;
        overlays = [ haskell-nix.overlay ];
      };
      project = pkgs.haskell-nix.cabalProject' {
        src = ./.;
        compiler-nix-name = "ghc98";
      };
      certs =
        import "${nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
    in {
      checks.${system}.smtp-mail = pkgs.testers.nixosTest {
        name = "smtp-mail";
        nodes.machine = { config, pkgs, ... }: {
          imports = [ "${nixpkgs}/nixos/tests/common/user-account.nix" ];
          services.postfix = {
            enable = true;
            enableSubmission = true;
            enableSubmissions = true;
            settings.main = {
              tlsTrustedAuthorities = "${certs.ca.cert}";
              smtpd_tls_chain_files = [
                certs."acme.test".key
                certs."acme.test".cert
              ];
            };
            submissionOptions = {
              smtpd_sasl_auth_enable = "yes";
              smtpd_client_restrictions = "permit";
              milter_macro_daemon_name = "ORIGINATING";
            };
            submissionsOptions = {
              smtpd_sasl_auth_enable = "yes";
              smtpd_client_restrictions = "permit";
              milter_macro_daemon_name = "ORIGINATING";
            };
          };

          security.pki.certificateFiles = [ certs.ca.cert ];

          networking.extraHosts = ''
            127.0.0.1 acme.test
          '';

          environment.systemPackages = [
            project.hsPkgs.integration-test.components.exes.integration-test
          ];
        };

        testScript = ''
          machine.wait_for_unit("postfix.service")
          machine.succeed("integration-test")
        '';
      };
    };
}
