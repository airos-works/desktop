import { pathExists } from '../path-exists'
import { IFoundEditor } from './found-editor'

/** Represents an external editor on Haiku */
interface IHaikuExternalEditor {
  /** Name of the editor. It will be used both as identifier and user-facing. */
  readonly name: string

  /** List of possible paths where the editor's executable might be located. */
  readonly paths: string[]
}

/** Where Haiku's packages and the user's own installs put applications. */
const appDirectories = [
  '/boot/system/apps',
  '/boot/system/non-packaged/apps',
  '/boot/home/config/apps',
  '/boot/home/config/non-packaged/apps',
]

const inAppDirectories = (...names: string[]) =>
  appDirectories.flatMap(directory => names.map(name => `${directory}/${name}`))

/**
 * This list contains all the external editors supported on Haiku. Add a new
 * entry here to add support for your favorite editor.
 **/
const editors: IHaikuExternalEditor[] = [
  { name: 'Pe', paths: inAppDirectories('Pe/Pe') },
  { name: 'Koder', paths: inAppDirectories('Koder/Koder', 'Koder') },
  { name: 'Genio', paths: inAppDirectories('Genio/Genio', 'Genio') },
  { name: 'StyledEdit', paths: inAppDirectories('StyledEdit') },
]

async function getAvailablePath(paths: string[]): Promise<string | null> {
  for (const path of paths) {
    if (await pathExists(path)) {
      return path
    }
  }

  return null
}

export async function getAvailableEditors(): Promise<
  ReadonlyArray<IFoundEditor<string>>
> {
  const results: Array<IFoundEditor<string>> = []

  for (const editor of editors) {
    const path = await getAvailablePath(editor.paths)
    if (path) {
      results.push({ editor: editor.name, path })
    }
  }

  return results
}
