{
  description = "QuickNotes reproducible build";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      quicknotes = pkgs.buildGoModule {
        pname = "quicknotes";
        version = "0.1.0";
        src = ./app;

        vendorHash = null;
        env.CGO_ENABLED = "0";
        ldflags = [ "-s" "-w" ];
      };
      docker = pkgs.dockerTools.buildImage {
        name = "quicknotes";
        tag = "lab11";
        created = "1970-01-01T00:00:01Z";

        uid = 65532;
        gid = 65532;

        copyToRoot = pkgs.buildEnv {
          name = "quicknotes-image-root";
          paths = [ quicknotes ];
          pathsToLink = [ "/bin" ];
        };

        extraCommands = ''
          mkdir -p data
          cp ${./app/seed.json} seed.json
        '';

        config = {
          Entrypoint = [ "/bin/quicknotes" ];
          ExposedPorts = { "8080/tcp" = {}; };
          User = "65532:65532";
          Env = [
            "ADDR=:8080"
            "DATA_PATH=/data/notes.json"
            "SEED_PATH=/seed.json"
          ];
        };
      };
    in
    {
      packages.${system} = {
        inherit quicknotes docker;
        default = quicknotes;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ go gopls golangci-lint ];
      };
    };
}