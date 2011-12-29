Momentum, a SPDY Server for Rack apps
========

Momentum is a SPDY server that aims to be drop-in compatible with existing Rack apps,
and to allow the app to use SPDY features that speed up the response times.

Rack apps can declare the resources the page is going to depend on while rendering the page.

Usage
-----
Momentum is implemented as a thin backend. It does not use much of thin, but the code for
interacting with the server process (signals, console output) is reused.
Suppose you have added `momentum` to your app's `Gemfile`, you can start `momentum` by running:

    bundle exec thin start -r momentum -b Momentum::ThinBackend

Backends
--------
There are three possible backends:

- `Local` will process the Rack apps in the SPDY server itself.
- `HTTP` will cause the SPDY server to act as a  SPDY --> HTTP proxy.
  This means that SPDY's long-lived connections can be used to improve loading times.
- `SpecialHTTP` will fork a custom-protocol server that listens on a Unix socket.
  Think unicorn, but without the HTTP parsing. The SPDY server will then fire requests
  at that socket by opening connections. This way, the SPDY `EventMachine` reactor can
  still function while processing Rack apps with quite long response times.
  The custom-protocol server will respond either directly with the response to the request,
  and subsequent body chunks, or can prepend to that a number of custom messages.


Taking advantage of SPDY Server Push
-------------------------------------

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