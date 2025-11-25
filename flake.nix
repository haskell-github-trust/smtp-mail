{
  description = "smtp-mail";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }: {
    overlays.default = final: prev: {
      haskellPackages = prev.haskellPackages.override {
        overrides = self: prev: {
          smtp-mail = self.callCabal2nix "smtp-mail" ./. { };
          integration-test = self.callCabal2nix "integration-test"
            ./nix-integration-test/integration-test { };
        };
      };
    };

    checks.x86_64-linux.smtp-mail = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux.extend self.overlays.default;
      certs =
        import "${nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
    in pkgs.testers.nixosTest {
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

        environment.systemPackages = [ pkgs.haskellPackages.integration-test ];
      };

      testScript = ''
        machine.wait_for_unit("postfix.service")
        machine.succeed("integration-test")
      '';
    };
  };
}
