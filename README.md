Momentum, a SPDY Server for Rack apps
=====================================


Momentum is a Rack-compatible web server for SPDY clients. Momentum can act as a reverse proxy, 
forwarding requests from SPDY-enabled browsers to your regular HTTP app server.
But since it is completely compatible with the Rack specification, you can also run any Rack app
purely on SPDY.

Usage
-----

Suppose you have added `momentum` to your app's `Gemfile`, you can start the SPDY server by running:

    bundle exec momentum
  
The `momentum` command behaves the same as `rackup`, it will try to run a `config.ru` file in the 
current directory.

You can also start Momentum from your code:

    require "momentum"
    EM.run {
      Momentum.start(Momentum::Adapters::Proxy.new('localhost', 3000))
    }

This will start Momentum on `0.0.0.0:5555` as a proxy to an HTTP server that should be running on
`localhost:3000`.

Backend
-------
As Momentum is Rack-based, the server will deliver all requests to a Rack app.
The simplest possible solution is to just use your regular Rack app with the Momentum backend.
SPDY requests to your app will cause your application code to be executed in the SPDY server 
itself. 

The Momentum backend provides functionality for deferred/asynchronous responses.
This works just like in a `Thin` environment: throwing `:async` will cause the
header reply to be postponed. Calling the proc stored in `env['async.callback']`
will send the headers. If you provide a body with callback functionality, you can
even use streaming bodies. [See here for an example from Thin.][thin_async]

As your app is probably not asynchronous, the event loop of the SPDY server will be 
blocked when running your app's code. This can cause timeouts and other problems if your 
application's response time is high (i.e. greater than 20 msecs). In this case, you can 
use an Adapter to connect the SPDY server to another backend.


Adapters
--------
Adapters are Rack apps. They can be thought of as middleware. If you do not want your App
to be executed within the SPDY server event loop (i.e. because it blocks), you should use an
Adapter.


### Momentum::Adapters::Proxy
The `Proxy` adapter will cause all requests on the SPDY connection to be forwarded to a 
given HTTP server. The SPDY server will act as an HTTP proxy. This way, the speedup provided 
by SPDY's long-lived connections can improve loading times for compatible clients.
However, no advanced features of the SPDY protocol, such as Server Push, can be used, as
they would requirecommunication betweeen the backend and the SPDY server before the response 
is sent.

Note that is is _not_ a SPDY/HTTPS proxy for proxying connections to arbitrary servers
through a SPDY tunnel as described in http://dev.chromium.org/spdy/spdy-proxy-examples.


### Momentum::Adapters::Accelerate
`Accelerate` will fork a custom-protocol server that listens on a Unix socket.
Think unicorn, but without the HTTP overhead. The SPDY server will fire requests
at that socket. This way, the SPDY EventMachine reactor can still function while 
heavy Rack apps are processed in the Unicorn-style worker process.
The protocol is binary with little overhead. It is custom because besides from
regular HTTP responses, special SPDY-related messages may be sent to the SPDY server,
such as the request for a SPDY server push.

HTTP Compliance is then achieved by having a slave HTTP server that forwards requests to
the master SPDY server.


### Momentum::Adapters::Defer
`Defer` will use the EventMachine thread pool to run your application code. No threads have to be
spawned. This reduces overhead in comparison to the Accelerate adapter, but also requires
your code to be thread-safe.

HTTP Compliance is then achieved by having a slave HTTP server that forwards requests to
the master SPDY server.


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


Performance
-----------
This project is in development. The performance is, to be honest, horrible.
I performe somed totally unscientific tests over a local network accessing the example app in
`examples/config.ru` from a media center-style box running Debian. Times were measured 
using the Chrome DOM inspector. The app in question displays a bare-bones HTML page, which 
in turn loads 3 javascripts from the server, which each have a size of 100KB.

### Initial request, load time of main page (~100B)
<dl>
  <dt>`ruby example/deferred_server.rb`</dt>
  <dd>27ms</dd>
  
  <dt>`thin start`</dt>
  <dd>5ms</dd>
</dl>

### Subsequent request, load time of main page (~100B)
<dl>
  <dt>`ruby example/deferred_server.rb`</dt>
  <dd>15ms</dd>
  
  <dt>`thin start`</dt>
  <dd>asdf</dd>
</dl>

### Average load time of the javascripts (100KB)
<dl>
  <dt>`ruby deferred_server.rb`</dt>
  <dd>124ms</dd>
  
  <dt>`thin start`</dt>
  <dd>20ms</dd>
</dl>

### Side test: Subsequent request, time until javascript is _requested_
This will become important when SPDY Push is used.
<dl>
  <dt>`ruby example/deferred_server.rb`</dt>
  <dd>210ms</dd>
  
  <dt>`thin start`</dt>
  <dd>180ms</dd>
</dl>

### Side test: Initial request, time until DOMContentLoaded
<dl>
  <dt>`ruby example/deferred_server.rb`</dt>
  <dd>450ms</dd>
  
  <dt>`thin start`</dt>
  <dd>380ms</dd>
</dl>

Deployment
----------
It is recommended to use the `Proxy` adapter for deploying, so you do not have to administer
two completely different frontends to your Rack app. The SPDY server falls back on the plain 
old HTTP server for processing, so no backend changes are required; SPDY-compatible clients
will use the improved connection, and HTTP clients will fall back.

In the future, it will be possible to reverse this architecture, having a secondary HTTP server
forward requests from "legacy" clients to the master SPDY server.


Compliance
----------
Momentum is meant to be compliant with this version of the SPDY spec:
http://mbelshe.github.com/SPDY-Specification/draft-mbelshe-spdy-00.xml


Credits
-------
Thanks to Ilya Grigorik for the great [SPDY parser gem](https://github.com/igrigorik/spdy).
Inspired by Roman Shterenzon's [SPDY server](https://github.com/romanbsd/spdy).

[thin_async]: https://github.com/macournoyer/thin/blob/master/example/async_app.ru