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

    Momentum.start(Momentum::Backend::Local.new(rack_app))

This will start Momentum using the `Local` backend (see below).


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
to be executed within the SPDY server event loop (because it blocks), you should use an
Adapter.

### Momentum::Adapters::Proxy
The `Proxy` adapter will cause all requests on the SPDY connectio to be forwarded to a 
given HTTP server. The SPDY server will act as an HTTP proxy. This way, the speedup provided 
by SPDY's long-lived connections can improve loading times for SPDY-compatible clients.
However, no advanced SPDY features like Server Push can be used, as they would require 
communication betweeen the backend and the SPDY server before the response is sent.

Note that is is _not_ a SPDY/HTTPS proxy for proxying connections to arbitrary servers
through a SPDY tunnel as described in http://dev.chromium.org/spdy/spdy-proxy-examples.

If you use your public HTTP server as the proxy target, the `Proxy` backend allows the 
app to be accessible through both HTTP and SPDY.


Deployment
----------
It is recommended to use the `Proxy` adapter for deploying, so you do not have to administer
two completely different frontends to your Rack app. The SPDY server falls back on the plain 
old HTTP server for processing, so no backend changes are required.

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