# Lab 11

## Task 1

### `flake.nix`
```nix
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
    in
    {
      packages.${system} = {
        inherit quicknotes;
        default = quicknotes;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [ go gopls golangci-lint ];
      };
    };
}
```

This `flake.nix` file fully complies with the task conditions:
- nixpkgs is pinned to `github:NixOS/nixpkgs/nixos-25.11` and `flake.lock` exists
- packages `quicknotes` and `default` are exposed to the `x86_64-linux`
- CGO_ENABLED set to 0
- vendorHash is set to null, because QuickNotes doesn't have external modules.
- in ldflags, -s and -w are used.
- devShell is exposed with go, gopls and golangci-lint

### `nix build .#quicknotes` Log excerpt
```
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ nix build .#quicknotes --print-build-logs
warning: Git tree '/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro' has uncommitted changes
warning: creating lock file "/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro/flake.lock":
• Added input 'nixpkgs':
    'github:NixOS/nixpkgs/b6018f8' (2026-06-30)
quicknotes> Running phase: unpackPhase
quicknotes> unpacking source archive /nix/store/s3kgv8c7q5vh49zf2aybs1zv4444lsii-app
quicknotes> source root is app
quicknotes> Running phase: patchPhase
quicknotes> Running phase: updateAutotoolsGnuConfigScriptsPhase
quicknotes> Running phase: configurePhase
quicknotes> Running phase: buildPhase
quicknotes> Building subPackage .
quicknotes> Running phase: checkPhase
quicknotes> ok          quicknotes      0.015s
quicknotes> Running phase: installPhase
quicknotes> Running phase: fixupPhase
quicknotes> shrinking RPATHs of ELF executables and libraries in /nix/store/q1c8vkqw81ibsgbd29bww1wqlmzdl8dh-quicknotes-0.1.0
quicknotes> shrinking /nix/store/q1c8vkqw81ibsgbd29bww1wqlmzdl8dh-quicknotes-0.1.0/bin/quicknotes
quicknotes> patchelf: cannot find section '.dynamic'. The input file is most likely statically linked
quicknotes> checking for references to /build/ in /nix/store/q1c8vkqw81ibsgbd29bww1wqlmzdl8dh-quicknotes-0.1.0...
quicknotes> patchelf: cannot find section '.dynamic'. The input file is most likely statically linked
quicknotes> patching script interpreter paths in /nix/store/q1c8vkqw81ibsgbd29bww1wqlmzdl8dh-quicknotes-0.1.0
quicknotes> stripping (with command strip and flags -S -p) in  /nix/store/q1c8vkqw81ibsgbd29bww1wqlmzdl8dh-quicknotes-0.1.0/bin
```

### Reproducibility verification
```
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ nix-store --query --hash "$(readlink result)"
sha256:1hv80kblj0zqcz82z0wihvxz63kylgwkqqgv5naykf0ar4f26w8k
```
```
thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro (feature/lab11)
$ MSYS_NO_PATHCONV=1 docker run --rm -it -v "$(pwd -W):/repo:ro" -w /repo nixos/nix sh

sh-5.3# nix --extra-experimental-features 'nix-command flakes' build .#quicknotes --out-link /tmp/result
sh-5.3# nix-store --query --hash "$(readlink /tmp/result)"
sha256:1hv80kblj0zqcz82z0wihvxz63kylgwkqqgv5naykf0ar4f26w8k
```

First output is a QuickNotes built in WSL2, second output is nixos/nix container and it has its own separate /nix/store. Both builds used the same source files and the same `flake.lock` and produced the same hash, which confirms reproducibility.

### Health check
```
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ nix build .#quicknotes
ADDR=127.0.0.1:18080 DATA_PATH=/tmp/quicknotes-lab11-notes.json SEED_PATH="$PWD/app/seed.json" ./result/bin/quicknotes &
qn_pid=$!
sleep 1
curl -s http://127.0.0.1:18080/health
kill "$qn_pid"


warning: Git tree '/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro' has uncommitted changes
[1] 7608
2026/10/15 23:41:34 quicknotes listening on 127.0.0.1:18080 (notes loaded: 4)
{"notes":4,"status":"ok"}
2026/10/15 23:41:35 shutting down
[1]+  Done                       ADDR=127.0.0.1:18080 DATA_PATH=/tmp/quicknotes-lab11-notes.json SEED_PATH="$PWD/app/seed.json" ./result/bin/quicknotes
```

Health check was done successfully. This script builds quicknotes with nix, launches the server, then does a healthcheck and then stops the server.

### Design questions
#### a) Why does go build not produce bit-identical outputs on two machines, even from the same Git SHA? (Hint: timestamps, vendor resolution, build IDs.)
Git SHA only pins the source files, but the environment can be not the same. Build ID is dependent on the project path. Basically, only changing the path will already produce different binaries. Build ID is also may be affected by build flags. Some external libraries may use timestamps during build and this will also lead to different binaries. 
#### b) vendorHash is a SHA over what, exactly? What happens if you set vendorHash = null;?
vendorHash is the hash of the Go external dependency files produced during Nix build. With `vendorHash = null`, Nix skips fetching the dependencies and it assumes they are already present in the `vendor/`. If they are not present, build will end with an error. `vendorHash = null` is also okay to use when you don't have any dependencies. It is used in this project, since QuickNotes doesn't have any.
#### c) flake.lock pins nixpkgs. Why is this the single most important file for reproducibility? What happens if you delete it before the second build?
`flake.nix` stores the branch name, in this case it's `nixos-25.11`. After some time, branch can move. `flake.lock` fixes the exact version. Removing the lock may result in the next build to use different packages and be different.

#### d) buildGoModule vs buildGoApplication — what's the difference? Which would you pick for QuickNotes and why?
buildGoModule is already provided by nixpkgs that was used, while buildGoApplication is a separate project. buildGoApplication requires making a specific file, where all external dependencies will be listed, buildGoModule collects the dependencies automatically. Since QuickNotes doesn't have any external dependencies, using buildGoApplication is useless in this case and will only result in creating unnecessary files.

## Task 2
### Extended flake.nix snippet
```nix
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
```

### Image-size comparison: Nix-built vs Lab 6 Docker-built

Nix-built image
```
thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro (feature/lab11)
$ docker image inspect quicknotes:lab11 --format 'size={{.Size}} user={{.Config.User}} entrypoint={{json .Config.Entrypoint}} ports={{json .Config.ExposedPorts}}'
size=21576682 user=65532:65532 entrypoint=["/bin/quicknotes"] ports={"8080/tcp":{}}
```

Docker-built images, here i have two docker images, but they have almost the same size, it differs just by 1 byte.
```
docker image inspect qn-lab6:run1 qn-lab6:run2 --format '{{.RepoTags}} size={{.Size}} id={{.Id}}'
[qn-lab6:run1] size=23010913 id=sha256:d9f2a3136acb02ae0d59a9d0f215282bd9aa97059bb667c44d740b33fd2dc430
[qn-lab6:run2] size=23010912 id=sha256:b06c1f45b24af40271626a89a4ad88a7672fb0ca34e185e9fcda7b8f6f7fbaa6
```

### sha256sum comparison
In WSL
```
thebruh@thebruh-PC:/mnt/c/Users/thebruh/Desktop/DevOpsCourse/DevOps-Intro$ sha256sum result
0d52c87bc54ed8ceb739094be42a86177bff3195e60a66d0c3445e06b2e377b9  result
```

In Docker container
```
thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro (feature/lab11)
$ MSYS_NO_PATHCONV=1 docker run --rm -it -v "$(pwd -W):/repo:ro" -w /repo nixos/nix sh
sh-5.3# nix --extra-experimental-features 'nix-command flakes' build .#docker --out-link /tmp/result
sha256sum /tmp/result
warning: Git tree '/repo' is dirty
0d52c87bc54ed8ceb739094be42a86177bff3195e60a66d0c3445e06b2e377b9  /tmp/result
```

SHA-256 is the same

### The two docker images --no-trunc digests proving Lab 6 differs
```
docker build --no-cache -t qn-lab6:run1 ./app
docker build --no-cache -t qn-lab6:run2 ./app

docker images --no-trunc qn-lab6
REPOSITORY   TAG       IMAGE ID                                                                  CREATED          SIZE
qn-lab6      run2      sha256:b06c1f45b24af40271626a89a4ad88a7672fb0ca34e185e9fcda7b8f6f7fbaa6   1 second ago     23MB
qn-lab6      run1      sha256:d9f2a3136acb02ae0d59a9d0f215282bd9aa97059bb667c44d740b33fd2dc430   10 seconds ago   23MB
```

### Design questions

#### e) dockerTools.buildImage produces a deterministic image. What does Docker's docker build do that introduces non-determinism, even from the same Dockerfile + Git SHA?
Same Dockerfile and Git SHA does not guarantee that every build input will be the same. Docker may use current time as a metadata and change the Image ID. Base image may update, for example, in my Dockerfile, `FROM golang:1.24` is used, next build can be different if it's updated.

#### f) For a security auditor, what can you prove with a reproducible image that you cannot prove with a signed-but-non-reproducible image?
signed-but-non-reproducible doesn't prove anything but that this build was signed by the owner, owner can still sign the changed code. However, reproducible image will produce the same hash every time with the same sources and build instructions. This can prove, that the distributor provides the users the exact same image as the image that security auditor built themselves.

#### g) What's the trade-off of Nix's reproducibility? Why is docker build still the default for most teams?
Nix requires learning it's functional programming language to master it, drastically increases build complexity and therefore setup time. `docker build` is much easier for many teams because Dockerfile it's easier to setup, many documentations and tutorials avaliable on internet. Nix is intrusive and replaces some of the standard tools which are natively supported by Docker, for example `docker build` is replaced with nix build. And generally, Nix is a niche technology, while Docker is universal and supported almost everywhere. 

### Bonus task
Bonus task was not attempted