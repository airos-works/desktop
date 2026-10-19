/**
 * fs-admin on Haiku: it has no native module there, and Haiku has no
 * administrator rights to ask for. Installing the command line tool is a
 * macOS feature, so these are never reached; they fail if they are.
 */
type Callback = (error: Error | null) => void

const unsupported = (callback: Callback) =>
  callback(new Error('fs-admin is not available on Haiku'))

export const testMode = false
export const unlink = (path: string, callback: Callback) =>
  unsupported(callback)
export const makeTree = (path: string, callback: Callback) =>
  unsupported(callback)
export const symlink = (target: string, path: string, callback: Callback) =>
  unsupported(callback)
export const recursiveCopy = (
  source: string,
  destination: string,
  callback: Callback
) => unsupported(callback)
