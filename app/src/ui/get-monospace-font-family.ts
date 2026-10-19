export const getMonospaceFontFamily = (): string => {
  // Haiku's web engine resolves the generic families to its serif face (see
  // body.platform-haiku in variables.scss), so name Haiku's own font first.
  if (__HAIKU__) {
    return "'Noto Sans Mono', 'DejaVu Sans Mono', monospace, 'Noto Color Emoji'"
  }
  // TODO: This is the same as the --font-family-monospace defined in
  // variables.scss but we could be more clever here and only pick
  // platform-specific fonts. Not sure if it matters.
  return "SFMono-Regular, Consolas, Liberation Mono, Menlo, monospace, 'Apple Color Emoji', 'Segoe UI', 'Segoe UI Emoji', 'Segoe UI Symbol'"
}
