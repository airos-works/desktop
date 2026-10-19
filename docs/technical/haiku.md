# GitHub Desktop on Haiku

The `haiku` branch of this fork builds GitHub Desktop as a Haiku (air/OS)
app. It runs on [Aurora](https://github.com/jmgasper/aurora), which hosts
Electron apps on Haiku: Node.js runs the main process, and each window is a
native Haiku window whose page is drawn by Summit's WebKit engine. This is an
unofficial port; GitHub does not support it.

## How it differs from the Linux build

A Haiku build is a Linux build (`__LINUX__`, and `process.platform` is
`linux` in the bundles) with `__HAIKU__` where Haiku differs:

- **Git** is Haiku's own (the `git` package). The package's `app/git` folder
  links it into the layout dugite expects of its embedded Git, and
  `LOCAL_GIT_DIRECTORY` points there (`app/src/lib/haiku/environment.ts`).
  Git LFS has no Haiku package, so its global filters are not installed.
- **Credentials** go to Haiku's key store. keytar's binding is a placeholder
  file (`script/haiku/keytar.node`) that Aurora's own keytar answers for; the
  first time, Haiku asks whether GitHub Desktop may use the keyring.
- **Git's prompts** reach the app through the trampolines
  (`vendor/desktop-trampoline`), built on Haiku. `git-credential-desktop`
  is found on `PATH`.
- **Signing in** opens the browser; GitHub sends it back to an
  `x-github-desktop-dev-auth:` link, of which the app is the preferred
  handler (Aurora's `setAsDefaultProtocolClient`). The browser starts the
  app with the link, and the running instance takes it. The OAuth token
  exchange goes through Node.js (`app/src/lib/haiku/node-fetch.ts`): the
  engine applies CORS to the app's pages, and that endpoint has none.
- **Integrations:** Terminal is the shell; Pe, Koder, Genio and StyledEdit
  are the editors (`app/src/lib/editors/haiku.ts`,
  `app/src/lib/shells/haiku.ts`); "Show in Tracker" opens Tracker.
- **Fonts:** Haiku's engine resolves the generic font families to a serif
  face, so `body.platform-haiku` names Noto Sans and Noto Sans Mono first.
- **No usage statistics** are sent to GitHub, notifications are not shown
  (as on Linux), and updates come through pkgman.
- fs-admin and desktop-notifications have no Haiku modules: fs-admin is a
  stand-in, desktop-notifications is never loaded. The syntax highlighter is
  one file (Aurora starts a file: page's workers from blobs, which cannot
  find chunks).

## Building

On Linux, with this repository's usual dependencies installed (Node.js from
`.nvmrc`, `yarn`):

```sh
script/haiku/build.sh            # webpack with DESKTOP_TARGET_PLATFORM=haiku → dist/haiku
```

Then on Haiku (or air/OS), with `gcc`, Git, Node.js 22 and Aurora 0.2 or
later installed, in a copy of `dist/haiku`:

```sh
./package.sh <output directory>  # github_desktop-<version>-<revision>-<arch>.hpkg
```

`package.sh` builds the native helpers (the trampolines, the hooks proxy,
printenvz), lays out the Git links and makes the launcher from Aurora's
`aurora-host` (`AURORA_HOST_BINARY`, by default the installed aurora
package's). Raise `REVISION` in it for a new package of the same version.

Install with `pkgman install github_desktop-*.hpkg`. The package requires
`aurora >= 0.2`, `cmd:node >= 22` and `cmd:git`; Deskbar's Applications menu
has GitHub Desktop.

## Debugging

Aurora's switches work in the app's `aurora.json` (`"env": {...}`) or when
running the build directly with `aurora dist/haiku/app`:
`AURORA_PAGE_CONSOLE=1` copies the page's console and uncaught errors to
stderr, `AURORA_TRACE_REMOTE=1` logs the page's Node.js requests and
`AURORA_REPL=<socket>` evaluates expressions in the main process
(`runtime/tools/aurora-repl.js` in Aurora).
