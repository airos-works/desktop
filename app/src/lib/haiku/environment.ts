import * as Path from 'path'

/**
 * Haiku builds (docs/technical/haiku.md) use Haiku's own Git through the
 * package's `git` folder, links laid out as dugite expects its embedded Git
 * (bin/git, libexec/git-core, share/git-core/templates). The trampolines are
 * in `desktop-trampoline`, which goes first on PATH so that Git finds
 * git-credential-desktop there. This runs in the main process, before any
 * window: renderers start with its environment.
 */
export function setupHaikuEnvironment(appDirectory: string) {
  if (!process.env.LOCAL_GIT_DIRECTORY) {
    process.env.LOCAL_GIT_DIRECTORY = Path.join(appDirectory, 'git')
  }

  const trampolines = Path.join(appDirectory, 'desktop-trampoline')
  const path = process.env.PATH ?? ''
  if (!path.split(':').includes(trampolines)) {
    process.env.PATH = path.length > 0 ? `${trampolines}:${path}` : trampolines
  }
}
