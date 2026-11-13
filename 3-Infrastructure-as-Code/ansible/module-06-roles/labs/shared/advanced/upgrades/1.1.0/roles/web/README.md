# Role `web`

EN: nginx + atomic releases on Ubuntu 24.04, Amazon Linux 2023 and AlmaLinux 9.
FR : nginx + versions atomiques sur Ubuntu 24.04, Amazon Linux 2023 et AlmaLinux 9.

```
/var/www/ans-lab/releases/<version>/index.html
/var/www/ans-lab/current  -> releases/<version>      (atomic switch)
/var/www/ans-lab/health/ok                            (present = /healthz 200, absent = 503: drain switch)
```

## Variables (`defaults/main.yml`)

| Variable | Default | Meaning |
|---|---|---|
| `web_site_root` | `/var/www/ans-lab` | site root (was `web_root`, deprecated in 1.1.0, removed in 2.0.0) |
| `web_keep_releases` | `3` | releases kept on disk; `0` keeps all |
| `web_release_version` | `v1` | release to deploy and make current |
| `web_mark_healthy` | `true` | create `health/ok` (set `false` while drained, Module 5) |
| `web_users` | `deploy`, `audit` | users to create: `{name: {comment, shell}}` |
| `web_site_extra_directives` | `[]` | extra lines in the nginx `server {}` block |

## Example

```yaml
- hosts: role_web
  become: true
  roles:
    - role: web
      vars:
        web_release_version: v2
```
