# static-web-app — KivuBrew website

Plain HTML/CSS/JS. No build step. The files in `site/` are copied as-is to nginx on EC2.

## Run locally

```bash
cd site
python3 -m http.server 8080   # open http://localhost:8080 (banner shows LOCAL)
```

## Release process

| Branch / tag | Deployed to | How |
|---|---|---|
| `main` | DEV | Infra team runs `terraform apply -replace=module.app_service.aws_instance.web` |
| `vX.Y.Z` tag | PROD | Release Manager opens a PR in the infra repo bumping `app_version` |

Cut a release:

```bash
git checkout main && git pull
git tag -a v1.0.0 -m "First production release"
git push origin v1.0.0
```

Tags are **immutable** — never move or delete a tag that PROD uses. Fix forward with a new tag.

> This repo must stay **public**: the EC2 instance clones it anonymously over HTTPS.
