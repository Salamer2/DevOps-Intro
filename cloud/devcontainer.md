# Codespaces setup

[devcontainer.json](../.devcontainer/devcontainer.json)
```json
{
  "name": "quicknotes-host",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {}
  },
  "forwardPorts": [8080],
  "postCreateCommand": "docker pull ghcr.io/salamer2/devops-intro/quicknotes:v0.1.0",
  "postStartCommand": "docker rm -f quicknotes 2>/dev/null; docker run -d --name quicknotes -p 8080:8080 ghcr.io/salamer2/devops-intro/quicknotes:v0.1.0"
}
```

Commands used:

```bash
gh codespace create -R Salamer2/DevOps-Intro -b feature/lab10 --devcontainer-path .devcontainer/devcontainer.json -s

gh codespace ports visibility 8080:public -c jubilant-space-journey-gjq56rrj6jwcpp67
gh codespace ports -c jubilant-space-journey-gjq56rrj6jwcpp67

# Shut down
gh codespace stop -c jubilant-space-journey-gjq56rrj6jwcpp67

# Teardown
gh codespace delete -c jubilant-space-journey-gjq56rrj6jwcpp67
```

Public URL while running: `https://jubilant-space-journey-gjq56rrj6jwcpp67-8080.app.github.dev`
