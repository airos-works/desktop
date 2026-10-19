import * as http from 'http'
import * as https from 'https'

/**
 * fetch() through Node.js, for Haiku builds. Their pages are web pages of
 * Haiku's engine, which applies CORS to a file: page's requests, and GitHub's
 * web endpoints (the OAuth token exchange) answer no CORS preflight. The
 * response is read whole.
 */
export function nodeFetch(url: string, init: RequestInit): Promise<Response> {
  return new Promise((resolve, reject) => {
    const target = new URL(url)
    const client = target.protocol === 'http:' ? http : https
    const headers: Record<string, string> = {}
    new Headers(init.headers).forEach((value, key) => {
      headers[key] = value
    })

    const request = client.request(
      target,
      { method: init.method ?? 'GET', headers },
      response => {
        const chunks = new Array<Buffer>()
        response.on('data', chunk => chunks.push(Buffer.from(chunk)))
        response.on('error', reject)
        response.on('end', () => {
          const responseHeaders = new Headers()
          for (const [key, value] of Object.entries(response.headers)) {
            if (value !== undefined) {
              responseHeaders.set(
                key,
                Array.isArray(value) ? value.join(', ') : value
              )
            }
          }
          resolve(
            new Response(Buffer.concat(chunks), {
              status: response.statusCode ?? 500,
              statusText: response.statusMessage ?? '',
              headers: responseHeaders,
            })
          )
        })
      }
    )
    request.on('error', reject)
    if (typeof init.body === 'string') {
      request.write(init.body)
    }
    request.end()
  })
}
