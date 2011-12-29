Backends
--------
- `Accelerate` will fork a custom-protocol server that listens on a Unix socket.
  Think unicorn, but without the HTTP parsing. The SPDY server will then fire requests
  at that socket by opening connections. This way, the SPDY `EventMachine` reactor can
  still function while processing Rack apps with quite long response times.
  The protocol is custom because besides from regular HTTP responses, special SPDY-related
  messages may be sent to the SPDY server, such as starting a resource push.
  
  HTTP Compliance is then achieved by having a slave HTTP server that forwards requests to
  the SPDY server.

TODO: Proper proxy headers for the Proxy backend

Taking advantage of SPDY Server Push
-------------------------------------

Using SPDY Server push requires the `Accelerate` backend.
The momentum server stores a `Momentum::AppInterface` object in `env['spdy']`.
`Momentum::AppInterface` provides several methods:

- `hint(url)` (SPDY Server Hint is deprecated?)

- `push(url)` initiates a SPDY push to the client.
  It should be called when the app can safely determine that the resource
  at `path` is going to be required to render the page.
  
  The SPDY server will then start processing the request immediately as if was sent as
  a separate request by the client.
  The virtual request will look to the application like a normal GET request from the same 
  client. Information that is duplicated from the initial request consists of:
    - Cookie
    - User-Agent
  
  Processing of the resource will occur in parallel to the processing of the original request.