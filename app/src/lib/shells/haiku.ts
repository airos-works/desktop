import { spawn, ChildProcess } from 'child_process'
import { parseEnumValue } from '../enum'
import { pathExists } from '../path-exists'
import { FoundShell } from './shared'
import {
  expandTargetPathArgument,
  ICustomIntegration,
  parseCustomIntegrationArguments,
  spawnCustomIntegration,
} from '../custom-integration'

/**
 * Haiku's terminals (builds with __HAIKU__). Named apart from the other
 * platforms' Shell enums: TypeScript would take an enum called Shell with
 * a Terminal member for macOS's.
 */
enum HaikuShell {
  Terminal = 'Terminal',
}

export { HaikuShell as Shell }
type Shell = HaikuShell

export const Default = HaikuShell.Terminal

export function parse(label: string): Shell {
  return parseEnumValue(HaikuShell, label) ?? Default
}

const TerminalPath = '/boot/system/apps/Terminal'

export async function getAvailableShells(): Promise<
  ReadonlyArray<FoundShell<Shell>>
> {
  return (await pathExists(TerminalPath))
    ? [{ shell: HaikuShell.Terminal, path: TerminalPath }]
    : []
}

export function launch(
  foundShell: FoundShell<Shell>,
  path: string
): ChildProcess {
  return spawn(foundShell.path, ['-w', path], {
    detached: true,
    stdio: 'ignore',
  })
}

export function launchCustomShell(
  customShell: ICustomIntegration,
  path: string
): ChildProcess {
  const argv = parseCustomIntegrationArguments(customShell.arguments)
  const args = expandTargetPathArgument(argv, path)
  return spawnCustomIntegration(customShell.path, args)
}
