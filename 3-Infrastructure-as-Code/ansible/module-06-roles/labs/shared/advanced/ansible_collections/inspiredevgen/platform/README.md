# inspiredevgen.platform

EN: Baseline and web roles for the DevOps Workshops lab fleet, and filters for release names.
FR : Rôles baseline et web pour le parc de lab DevOps Workshops, et filtres pour les noms de versions.

| Content | Use |
|---|---|
| `inspiredevgen.platform.baseline` (role) | packages, admin users (sudo/wheel), time zone, message of the day |
| `inspiredevgen.platform.web` (role) | nginx + atomic releases + `/healthz` drain switch (depends on `baseline`) |
| `inspiredevgen.platform.release_sort` (filter) | `['v1.9','v1.10'] \| inspiredevgen.platform.release_sort` → natural order |
| `inspiredevgen.platform.release_previous` (filter) | the release before a given one |

Requires ansible-core >= 2.21. Supported: Ubuntu 24.04, Amazon Linux 2023, AlmaLinux 9.

```yaml
# requirements.yml of a project that uses it: pin a TAG
collections:
  - name: https://github.com/<you>/ansible-platform-collection.git
    type: git
    version: v1.0.0
```

See [CHANGELOG.md](CHANGELOG.md).
