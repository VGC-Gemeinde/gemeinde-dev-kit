# gemeinde-dev-kit

Shared development tooling of the VGC Gemeinde projects (`gemeinde-tours`, `buli-hub`): one place
for the Spec Kit workflow and the Claude Code skills, so the projects stay alike and a fix lands
everywhere.

| Part | What it is | Where |
|---|---|---|
| Spec Kit extension `gemeinde` | Gate 1 (mockups, before `/speckit-plan`) and Gate 3 (Definition of Done, after `/speckit-converge`) as mandatory hooks | `speckit/extension/` |
| Spec Kit preset `gemeinde` | Spec, plan and tasks templates: UX & Mockups section, pinned stack, mandatory tests | `speckit/preset/` |
| Claude Code plugin `gemeinde-dev` | Shared skills, e.g. `dependency-update` | `plugins/gemeinde-dev/` (marketplace `gemeinde`) |

Nothing here is project-specific. Each project's rules, stack and checks live in its own
constitution, which the gates read (see "Workflow profile").

## Spec Kit

Requires `specify-cli` 1.1.3 (`uv tool install specify-cli --from
git+https://github.com/github/spec-kit.git@v1.1.3`).

In a project, once (`--here` keeps existing files):

```bash
specify init --here --non-interactive --integration claude --script sh
```

Install a released version. The release tag in the URL is the version pin; `--force` replaces an
installed one:

```bash
V=1.0.0
specify extension add gemeinde --from https://github.com/VGC-Gemeinde/gemeinde-dev-kit/releases/download/v$V/gemeinde-extension-$V.zip
specify preset add --from https://github.com/VGC-Gemeinde/gemeinde-dev-kit/releases/download/v$V/gemeinde-preset-$V.zip
```

`specify extension add --from` asks for confirmation. To try local changes before a release:
`specify extension add --dev <kit>/speckit/extension --force` and
`specify preset add --dev <kit>/speckit/preset`.

Template resolution: a project's `.specify/templates/overrides/` beats the preset, the preset beats
Spec Kit's core templates. A project keeps an override only where it needs stack-specific
scaffolding the generic template cannot give.

### Workflow profile

The gates and templates read a `### Workflow profile` section under **Development Workflow** in
`.specify/memory/constitution.md`, next to the **Definition of Done**. Every key is required; write
"None" where it does not apply.

```markdown
### Workflow profile

- **Viewers**: who can see the app's views and how they differ (e.g. public visitor, signed-in
  player, staff).
- **Design sources**: files to read before a mockup (design system, tokens file, where fonts load).
- **Mockup frame**: the widths and themes every mockup and every in-app check covers.
- **Checks**: the Definition of Done commands, in order, with caveats (e.g. "ask before the
  integration tests: they truncate the local database").
- **Copy checks**: the copy rules to grep changed files for.
- **Running-app check**: how to run the app for the visual check.
- **Dev tooling to extend**: galleries, personas or fixtures a feature extends, or "None".
- **Living documents**: what is kept current (architecture map, design system, runbook).
- **Legacy documents**: documents that are history, and the backlink line they receive.
- **Commit target**: the branch a feature commits to.
```

## Claude Code plugin

Each project enables it for everyone who opens it, in `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "gemeinde": { "source": { "source": "github", "repo": "VGC-Gemeinde/gemeinde-dev-kit" } }
  },
  "enabledPlugins": { "gemeinde-dev@gemeinde": true }
}
```

Its skills appear as `gemeinde-dev:<skill>`. New shared skills go into
`plugins/gemeinde-dev/skills/<name>/SKILL.md`.

## Releasing

1. Bump the version in what changed: `speckit/extension/extension.yml`,
   `speckit/preset/preset.yml`, `plugins/gemeinde-dev/.claude-plugin/plugin.json` (and its entry in
   `.claude-plugin/marketplace.json`).
2. `claude plugin validate --strict .` and `claude plugin validate --strict plugins/gemeinde-dev`.
3. `scripts/build-release.sh`, then `gh release create v<version> dist/*.zip`.
4. Re-install in the projects with the new version and review their diffs.
