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
  
The `momentum` command behaves equivalent to `rackup`, it will try to run a `config.ru` file in the current directory.

You can also start Momentum from your code:

    Momentum.start(Momentum::Backend::Local.new(rack_app))

This will start Momentum using the `Local` backend (see below).


Backends
--------
A Momentum backend is the component that handles incoming SPDY requests.
Currently, two backends are implemented:

### Momentum::Backend::Local
The `Local` backend will process the Rack apps in the SPDY server itself.
Requests to the app will be handled in the event loop of the SPDY server.
This can probably cause timeouts and other problems if your Rack app's response time
is high.

This backend provides functionality for deferred/asynchronous responses.
This works just like in a `Thin` environment: throwing `:async` will cause the
header reply to be postponed. Calling the proc stored in `env['async.callback']`
will send the headers. If you provide a body with callback functionality, you can
even use deferred bodies. [See here for an example from Thin.](thin_async)


*This backend is to be used for testing only, as it provides no HTTP fallback.*

### Momentum::Backend::Proxy
The `Proxy` backend will cause the SPDY server to forward requests to a given HTTP 
server, acting as an HTTP *reverse* proxy. This way, the speedup provided by SPDY's 
long-lived connections can improve loading times for SPDY-compatible clients.
However, no advanced SPDY features like Server Push can be used.

Note that is is _not_ a SPDY/HTTPS proxy for proxying connections to arbitrary servers
through a SPDY tunnel as described in http://dev.chromium.org/spdy/spdy-proxy-examples.

*Together with the original HTTP server, the `Proxy` backend allows the app to be
accessible through both HTTP and SPDY.*


Deployment
----------
Currently, it's recommended to use the `Proxy` backend for deploying, so you do not have to administer
two completely different frontends to your Rack app.

The SPDY server falls back on the plain old HTTP server for processing, so no backend changes are required.

In the future, it will be possible to reverse the architecture, having a secondary HTTP server
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