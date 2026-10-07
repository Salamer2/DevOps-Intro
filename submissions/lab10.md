# Lab 10. Cloud Computing

## New workflow ```release.yml```

At first, i collected the latest versions of the required third-party actions and their SHAs
```
gh release view --repo docker/login-action --json tagName --jq .tagName
gh release view --repo docker/build-push-action --json tagName --jq .tagName
gh release view --repo docker/metadata-action --json tagName --jq .tagName
gh release view --repo docker/setup-buildx-action --json tagName --jq .tagName

v4.6.0
v7.4.0
v6.2.0
v4.4.1
```


```
gh api repos/docker/login-action/commits/v4.6.0 --jq .sha
gh api repos/docker/build-push-action/commits/v7.4.0 --jq .sha
gh api repos/docker/metadata-action/commits/v6.2.0 --jq .sha
gh api repos/docker/setup-buildx-action/commits/v4.4.1 --jq .sha

dbcb813823bdd20940b903addbd779551569679f
c3c9e263c25d99ce0380d002d59b67737d91b0dc
dc802804100637a589fabce1cb79ff13a1411302
f87e5991a6d7451dcb8d9637bfbc97413f497069
```

Then the new workflow ```release.yml``` was created

### Making the tag and pushing it
```
git tag -a v0.1.0 -m "Lab 10 release"
git push origin v0.1.0
```

URL of a successfull CI-release run: https://github.com/Salamer2/DevOps-Intro/actions/runs/37662313313/job/112932655134 \
Registry URL: ```ghcr.io/salamer2/devops-intro/quicknotes:v0.1.0```


### Pulling the image
The image was successfully pulled.
```
thebruh@thebruh-PC MINGW64 ~/Desktop/DevOpsCourse/DevOps-Intro (feature/lab10)
$ docker pull ghcr.io/salamer2/devops-intro/quicknotes:v0.1.0
v0.1.0: Pulling from salamer2/devops-intro/quicknotes
44136fa355b3: Already exists
47d9538611fa: Pull complete
91d42874255a: Pull complete
d25c7cef9286: Pull complete
481d14300ae4: Pull complete
3b9cd641a3a7: Download complete
Digest: sha256:008a15d3924234476621597bc4da1c753baa472b145e2120c156851bb7d6abb1
Status: Downloaded newer image for ghcr.io/salamer2/devops-intro/quicknotes:v0.1.0
ghcr.io/salamer2/devops-intro/quicknotes:v0.1.0
```

### Design questions

#### a) OIDC vs GITHUB_TOKEN — for pushing to ghcr.io from the same repo, GITHUB_TOKEN with packages: write is enough. When would you reach for OIDC instead, and what does it give you that GITHUB_TOKEN doesn't?
OICD is required when pushing to the external cloud providers, because it is standartized. While GITHUB_TOKEN is made for github only, and cloud providers may not know what to do with it. The main advantage of using OIDC is safety for pushing to external clouds. It allows short-lived and secure access, therefore it eliminates storing any long-living secrets.
#### b) :latest tag vs :v0.1.0 immutable tag — Lab 6 covered why :latest is mutable. So why do you still ship a :latest tag alongside the immutable one in production releases?
Because in this case :latest is made for consumer convenience. Most of the times, consumers don't need reproducibility at all, they just want a latets working version. In the other time, immutable tags are made for deterministic deploys that requre a higher level of reliability.
#### c) packages: write scope only — what's the principle, and what concrete attack does the narrow scope prevent vs write: all?
With `write:all`, possible hacker gains access to the whole repository. They will be able to control any code, create malicious releases, read secrets, etc. Meanwhile, `packages: write` narrows the attack possibility. Hacker will be able to mess with the current image, but won't be able to spread to the whole repo.