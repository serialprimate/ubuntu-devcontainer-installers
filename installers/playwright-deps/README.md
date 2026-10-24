# Playwright dependencies installer

## Purpose

Installs the reviewed Ubuntu libraries, fonts and tools for bundled Chromium and Chromium Headless Shell. Projects separately own their Playwright npm packages, JavaScript or TypeScript tests, browser downloads and browser storage. The installer does not install Node.js, npm packages, browser binaries, a global `playwright` command or a browser service.

Included in collection version `0.6.0`, in both the source tree and OCI payload. Older collection releases do not contain this installer. Registry consumption requires verified publication through the [release procedure](../../docs/releasing.md).

## Supported platform

Ubuntu 26.04 LTS on `linux/amd64`, executed as root during an image build. The supported Playwright targets are **1.64.0 and 1.64.1**, with **1.64.1** as the release-fixed default. Project-local qualification uses Node.js 24 and tests both Chromium executable paths plus the embedded CLI; see the [testing guide](../../docs/testing.md#playwright-dependency-qualification) for scope and commands.

The default was upgraded from 1.64.0 after all three 1.64.1 npm packages passed the seven-day minimum release age. The youngest package, `@playwright/test@1.64.1`, was published on 2026-10-14 at 11:58:13.696 UTC and became eligible on 2026-10-21 at that time. Explicit 1.64.0 selection remains supported. Both exact releases share the same reviewed dependency profile; the installer never follows npm's mutable `latest` tag or infers compatibility with other patches or minor versions.

Firefox, WebKit, branded Google Chrome and Microsoft Edge are outside this dependency profile. There is no browser selector.

## Prerequisites

`apt-get` and the intrinsic Ubuntu commands used by the [platform checks](../../lib/platform.sh) must be available. Node.js, npm and a project checkout are **not** prerequisites for this installer.

For the complete project workflow, explicitly compose [`apt-packages`](../apt-packages/README.md) for Node.js prerequisites and HTTPS certificate trust, [`node`](../node/README.md), this installer and a development user established through [`user`](../user/README.md). Neither this installer nor the Node.js installer invokes the other. Project package/browser installation runs as the development user without sudo.

## Usage

Dependency installer invocation syntax:

```text
install.sh [--playwright-version VERSION] [--help]
```

## Options

- `--playwright-version VERSION`: selects the dependencies reviewed for an exact stable Playwright release. May be specified once, with a separate value. Supported values are `1.64.0` and `1.64.1`; the default is `1.64.1`.
- `--help`: prints help, including the default and supported targets, without changing system state.

The selector identifies the underlying Playwright release, not the version of a separately published CLI wrapper. It does not install an npm package. Empty values, leading-zero version components, ranges, partial versions, aliases, tags, prereleases and build metadata are rejected. Well-formed but unsupported versions fail with the supported-version list before APT changes. Unknown options, positional arguments, attached option forms and repeated selectors are rejected.

Omitting the selector uses this collection release's fixed baseline; it never queries upstream. Specify it explicitly to keep image-build intent visible when updating the installer collection. The image build cannot detect a project subsequently installing a different npm version: consumers must coordinate the selector and project lockfile.

## Installed files and commands

The profile is the deduplicated union of the upstream Ubuntu 26.04 `tools` and `chromium` groups: 33 direct package names in the installer's [reviewed array](install.sh), reviewed against the identical groups in [Playwright 1.64.0 source commit 606ecd8b34bac100db32561b6278ffd76e5eb3cd](https://github.com/microsoft/playwright/blob/606ecd8b34bac100db32561b6278ffd76e5eb3cd/packages/playwright-core/src/server/registry/nativeDeps.ts) and [Playwright 1.64.1 source commit cfe490d941f992655948eee8fd4fd94e1c4234bf](https://github.com/microsoft/playwright/blob/cfe490d941f992655948eee8fd4fd94e1c4234bf/packages/playwright-core/src/server/registry/nativeDeps.ts). No additional Ubuntu packages are introduced by 1.64.1 support.

Ubuntu packages supply shared libraries, font assets and tools including `Xvfb`. Installing Xvfb does not create a display session or desktop. The documented headless workflow does not invoke it. No installer-specific runtime configuration, user-owned cache, environment variable, entrypoint or service registration is created.

APT installs without recommended packages and owns normal transitive resolution. Initial resolution against a fresh Ubuntu 26.04 image selected 117 new packages, about 92 MB of archives and 333 MB of installed space. Those are observations, not size guarantees; repositories and base-image contents change. The complete image also contains explicitly selected Node.js and other tools. Browser binaries consume project-local storage separately.

## Repeated invocation

**Idempotent for the selected profile.** Default selection of `1.64.1` and explicit selection of either supported version ensure the same package requirements. Successive 1.64.0/1.64.1 invocations reuse the shared profile without removing packages or changing project-local npm versions. Every invocation independently refreshes APT indexes, installs required packages and cleans APT metadata/caches. It does not remove unrelated or previously installed packages.

Profile selection does not pin Ubuntu package binaries; APT still uses versions available in configured repositories. If additional profiles are introduced, successive selections are not isolated environments or a mechanism for uninstalling/downgrading another profile. Known incompatible combinations must be resolved before support is advertised.

## Network sources and integrity

The installer uses only configured Ubuntu APT sources and their trusted keyrings. Package indexes are mutable; APT verifies repository metadata and packages. No repository, signing key or insecure fallback is added. The selected Playwright version/profile mapping is bundled locally and does not require npm or upstream discovery.

The separate project workflow uses the configured npm registry, normally `https://registry.npmjs.org/`, and Playwright's browser download servers, including `https://cdn.playwright.dev/` and `https://playwright.download.prss.microsoft.com/`, with upstream-managed redirects/fallbacks. It requires network access during setup. Tests and CLI interactions can subsequently use local content without external networking.

Project lockfiles verify npm package content against registry integrity metadata; they do **not** verify subsequently downloaded browser archives. The reviewed upstream downloader uses HTTPS and transfer checks rather than pinned browser-archive digests. Project-local storage does not remove that residual trust requirement. Consumers needing stronger browser integrity require a separately reviewed acquisition mechanism. The dependency installer does not perform or certify browser downloads and has no controlled-risk download option.

## Examples

### Compose image components explicitly

The following is a focused source-tree Dockerfile fragment for an existing Ubuntu 26.04 stage configured with `SHELL ["/bin/bash", "-euo", "pipefail", "-c"]`. Its build context is the `0.6.0` repository root:

```dockerfile
# Copies the source collection with its installer-relative bundled-library layout
COPY installers /opt/ubuntu-devcontainer-installers/installers

# Copies the shared libraries beside the source installer collection
COPY lib /opt/ubuntu-devcontainer-installers/lib

# Composes toolchain prerequisites, Node.js, Chromium dependencies and the development identity
RUN /opt/ubuntu-devcontainer-installers/installers/apt-packages/install.sh \
        --package ca-certificates --package curl --package gnupg \
    && /opt/ubuntu-devcontainer-installers/installers/node/install.sh --node-version 24 \
    && /opt/ubuntu-devcontainer-installers/installers/playwright-deps/install.sh \
        --playwright-version 1.64.1 \
    && /opt/ubuntu-devcontainer-installers/installers/user/install.sh

USER dev
```

For OCI consumption, use collection `0.6.0` through the [root README's consumption example](../../README.md#oci-consumption), preferably pinned to its qualified immutable digest after publication. Local candidates can be built and verified through the [candidate interfaces](../../docs/testing.md#oci-candidate-verification); they do not establish registry availability or authorise development-profile migration.

### Establish project-owned packages and command resolution

Run setup inside a writable project checkout as the development user. Initial package selection, which creates or updates the project manifest and lockfile, is explicit:

```bash
npm install --save-dev --save-exact --ignore-scripts --min-release-age=7 @playwright/test@1.64.1
```

Subsequent installs use the committed lockfile and do not select a new version:

```bash
npm ci --ignore-scripts --min-release-age=7
```

Script execution is disabled in this minimal workflow; other projects may have separately reviewed packages that require scripts. Do not silently enable them. The release-age option requires an npm version supporting it; use the supported Node.js composition and fail clearly rather than omit the requested control.

The checked-in [project fixture](../../tests/integration/playwright-deps/project) supplies the exercised examples. For a consuming project without a source checkout, save the following complete helper as `project-playwright.cjs` in its root. It resolves the local test package's executable, sets the browser path, and runs from its own project root independently of the caller's working directory:

```javascript
// Resolve project-local packages and browser storage independently of the caller's directory.
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const [storage, ...args] = process.argv.slice(2);
if (!['separate', 'package'].includes(storage) || args.length === 0) {
    console.error('Usage: node project-playwright.cjs <separate|package> <playwright arguments...>');
    process.exit(1);
}
const cli = path.join(path.dirname(require.resolve('@playwright/test/package.json')), 'cli.js');
const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: __dirname,
    stdio: 'inherit',
    env: {
        ...process.env,
        PLAYWRIGHT_BROWSERS_PATH: storage === 'package' ? '0' : path.join(__dirname, 'ms-playwright'),
    },
});
if (result.error) console.error(result.error.message);
process.exit(result.status ?? 1);
```

Save this complete test configuration as `playwright.config.cjs`, adapting `testMatch` to your own JavaScript or TypeScript tests:

```javascript
// Exercise the two Chromium executable paths without inheriting a channel into Headless Shell.
module.exports = {
    testMatch: ['smoke.spec.cjs', 'smoke.spec.ts'],
    workers: 1,
    retries: 0,
    timeout: 15000,
    reporter: 'line',
    use: { browserName: 'chromium', headless: true },
    projects: [
        { name: 'chromium-new-headless', use: { channel: 'chromium' } },
        { name: 'chromium-headless-shell' },
    ],
};
```

Save this independent CLI configuration as `playwright-cli.config.json`:

```json
{
  "browser": {
    "browserName": "chromium",
    "launchOptions": {
      "channel": "chromium",
      "headless": true
    }
  }
}
```

The fixture's `smoke.spec.cjs` and `smoke.spec.ts` use only in-memory HTML and exercise JavaScript execution and Playwright's built-in TypeScript transform. A minimal project-owned JavaScript test can be saved as `smoke.spec.cjs`:

```javascript
const { test, expect } = require('@playwright/test');

test('browser interaction', async ({ page }) => {
    await page.setContent('<button onclick="this.textContent = \'Done\'">Run</button>');
    await page.getByRole('button').click();
    await expect(page.getByRole('button')).toHaveText('Done');
});
```

Playwright does not type-check tests: projects wanting type checking separately select a local TypeScript compiler and run `tsc --noEmit`. Experimental TypeScript syntax outside Playwright's transform support may need project-owned precompilation; no global TypeScript installation is implied.

A bare global command is not needed. `npx --no-install` prevents opportunistic installation but does not alone prove local resolution if a global command is available; the helper explicitly selects the project package.

### Retain browsers in a separate project directory

The helper's `separate` mode sets `PLAYWRIGHT_BROWSERS_PATH` to an absolute project-root `ms-playwright` path on **every** invocation. Install both Chromium variants, then run tests and an independently configured CLI session:

```bash
node project-playwright.cjs separate install chromium
node project-playwright.cjs separate test
node project-playwright.cjs separate cli -s=example open about:blank --config=playwright-cli.config.json
node project-playwright.cjs separate cli -s=example close
```

These commands do not use `--with-deps`. A project does not elevate privileges or install Ubuntu packages at runtime. Close CLI sessions after use and ensure failure cleanup in automated callers. The qualification fixture demonstrates interaction/assertion and unconditional cleanup.

The browser directory survives `npm ci`. Delete `ms-playwright/` to reset its contents; the explicit install step restores required revisions. Playwright also tracks package references and removes unused revisions. Disabling its garbage collection is a consumer choice that needs a disk-growth policy, not a default of this installer.

### Keep browsers beneath node_modules instead

The helper's `package` mode sets `PLAYWRIGHT_BROWSERS_PATH=0` for installation, testing and CLI use:

```bash
node project-playwright.cjs package install chromium
node project-playwright.cjs package test
node project-playwright.cjs package cli -s=example open about:blank --config=playwright-cli.config.json
node project-playwright.cjs package cli -s=example close
```

Browsers live beneath the resolved `playwright-core` package's `.local-browsers` directory. `npm ci` replaces `node_modules` and removes those browsers, so repeat the browser-installation step afterward. Multiple resolved Playwright installations can have separate browser copies.

### Make headless modes and storage exclusions explicit

The fixture's [test configuration](../../tests/integration/playwright-deps/project/playwright.config.cjs) runs regular Chromium with `channel: 'chromium'` and `headless: true`, plus Headless Shell with headless execution and no channel. Both execute the same small interaction test. Docker itself does not select new headless mode. Do not use `--only-shell` or `--no-shell` when exercising both paths; narrower consumer workflows may deliberately select only one.

The [CLI configuration](../../tests/integration/playwright-deps/project/playwright-cli.config.json) separately selects Chromium, channel `chromium` and headless operation. It does not inherit Playwright Test configuration. An unconfigured CLI can select branded Chrome instead. Neither headless workflow requires a GUI or Xvfb wrapper. The fixture preserves upstream Chromium sandbox defaults; the observed launch arguments include `--no-sandbox` even though the process runs as the development user. Non-root/headless qualification therefore does not establish browser sandbox isolation. Untrusted browsing requires a separately reviewed isolation policy; this installer does not configure one.

Use applicable Git and Docker build-context exclusions. A focused ignore-file fragment for the example project is:

```gitignore
/ms-playwright/
/node_modules/
/.cache/
/.playwright/
/.playwright-cli/
/.qualification/
/test-results/
/playwright-report/
```

Add the applicable entries to both `.gitignore` and `.dockerignore`; Git ignoring alone does not prevent broad Docker `COPY` instructions from including browser downloads. Persistence follows the workspace's existing mount, not the directory name. No extra volume is required if the checkout is already persisted. Separate projects can manage their own space, but may duplicate identical browser downloads.

## Known limitations

Only the two explicitly supported targets are qualified. Upgrading a project package can require another Ubuntu dependency profile or image rebuild; local browser downloads do not establish operating-system compatibility. Unsupported targets fail rather than select the nearest supported profile.

The embedded `playwright cli` is included in the stable project-local Playwright package. The separately published `@playwright/cli` wrapper is not required or qualified here. In the reviewed `0.1.22` wrapper, underlying Playwright dependencies are alpha builds; do not substitute the wrapper's version for this installer's target or assume its browser requirements match stable Playwright.

Use container-platform browser binaries rather than reusing a cache populated by a different native host operating system. Browser storage belongs to the development user and must not be trusted as an executable source by root or a different security identity. Headed operation needs separately configured display infrastructure. This feature does not add container privilege, host IPC, a desktop, automatic browser download hooks or a shared system-wide cache.
