Accelerate adapter
--------
- `Accelerate` will fork a custom-protocol server that listens on a Unix socket.
  Think unicorn, but without the HTTP overhead. The SPDY server will fire requests
  at that socket. This way, the SPDY `EventMachine` reactor can still function while 
  heavy Rack apps are processed in the Unicorn-style worker process.
  The protocol is binary with little overhead. It is custom because besides from
  regular HTTP responses, special SPDY-related messages may be sent to the SPDY server,
  such as the request for a SPDY server push.
  
  HTTP Compliance is then achieved by having a slave HTTP server that forwards requests to
  the front-end SPDY server.


Taking advantage of SPDY Server Push
-------------------------------------
A `Momentum::AppDelegate` object is available in `env['spdy']` when running on Momentum.
The public API for this object currently consists of just one method, `push`.
It should be called when the app can safely determine that the resource
at `path` is going to be required to render the page.

Using it requires the `Accelerate` backend. If you are not running the `Accelerate` adapter,
calling `push` will result in a no-op. If you _are_ running that adapter, calling `push(url)`
will initiate a SPDY Server Push to the client.

The SPDY server will be informed of the app's push request, and will start processing the 
request immediately as if was sent as a separate request by the client.

The virtual request will look to the application like a normal GET request from the same 
client. Information that is duplicated from the initial request consists of:
    - Cookie
    - User-Agent

-> Caching / Server Hint?