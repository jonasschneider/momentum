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


Taking advantage SPDY Server Push
-------------------------------------

The momentum server stores a `Momentum::AppInterface` object in `env['spdy']`.
`Momentum::AppInterface` provides several methods:

- `add_resource(path)` should be called when the app can safely determine that the resource
  at `path` is going to be required to render the page.
  
  The `momentum` server will then start processing the request immediately as if was sent as
  a separate request by the client.
  The virtual request will look to the application like a normal GET request from the same 
  client. Information that is duplicated from the initial request consists of:
    - Cookie
    - User-Agent
  
  Processing of the resource will occur in parallel to the processing of the original request.

Todo
----
- Keep a thread pool for secondary requests or something?


Credits
-------
Code parts are borrowed from `https://github.com/romanbsd/spdy`