#!/usr/bin/env python3
# =============================================================================
# EN: Some inventory plugins (azure_rm, for one) silently IGNORE unknown options: a typo such as
#     "include_vm_resource_group" (no s) means "every resource group". This checks each plugin config's keys
#     against the plugin's own documentation (ansible-doc). Use it in CI next to ansible-lint.
#       python3 check-inventory-options.py path/or/folder [...]
# FR : Certains plugins d'inventaire (azure_rm, par exemple) IGNORENT en silence les options inconnues : une
#     faute comme « include_vm_resource_group » (sans s) signifie « tous les groupes de ressources ». Ce script
#     compare les clés de chaque configuration à la documentation du plugin (ansible-doc). À utiliser en CI.
# =============================================================================
import glob
import json
import os
import subprocess
import sys

import yaml

_cache = {}


def plugin_options(name):
    if name not in _cache:
        out = subprocess.run(["ansible-doc", "-t", "inventory", "-j", name], capture_output=True, text=True, check=False)
        try:
            _cache[name] = set(json.loads(out.stdout)[name]["doc"]["options"]) | {"plugin"}
        except (ValueError, KeyError):
            _cache[name] = None
    return _cache[name]


def files(args):
    for a in args or ["."]:
        if os.path.isdir(a):
            yield from sorted(glob.glob(os.path.join(a, "**", "*.y*ml"), recursive=True))
        else:
            yield a


failed = 0
for f in files(sys.argv[1:]):
    try:
        with open(f, encoding="utf-8") as fh:
            cfg = yaml.safe_load(fh)
    except yaml.YAMLError as e:
        print(f"❌ {f}: YAML error: {e}")
        failed += 1
        continue
    if not isinstance(cfg, dict) or "plugin" not in cfg:
        continue  # EN: not a plugin config (a static inventory or group_vars) / FR : pas une configuration de plugin
    known = plugin_options(cfg["plugin"])
    if known is None:
        print(f"⚠️  {f}: plugin {cfg['plugin']} not found (collection installed?)")
        continue
    unknown = sorted(set(cfg) - known)
    if unknown:
        print(f"❌ {f}: unknown option(s) for {cfg['plugin']}: {', '.join(unknown)}")
        failed += 1
    else:
        print(f"✅ {f}")
sys.exit(1 if failed else 0)
