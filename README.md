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

You can also start Momentum from your code:

    Momentum.start(rack_app)

This will start Momentum with the `Local` backend (see below).


Backends
--------
A Momentum backend is the component that handles incoming SPDY requests.
Currently, two backends are implemented:

- `Momentum::Backend::Local` will process the Rack apps in the SPDY server itself.
  Requests to the app will be handled in the event loop of the SPDY server.
  This can probably cause timeouts and other problems if your Rack app's response time
  is high.
  
  This backend is to be used for testing only, as it provides no HTTP fallback.

- `Momentum::Backend::Proxy` will cause the SPDY server to forward requests to a given 
  HTTP server, acting as an HTTP proxy. In this way, the speedup provided by SPDY's 
  long-lived connections can improve loading times for regular HTTP apps.
  However, no advanced SPDY features like Server Push can be used.
  
  Together with the original HTTP server that is proxied through SPDY, both HTTP and SPDY
  protocols are accessible from the outside.


Deployment
----------
Currently, it's recommended to use the `Proxy` backend for deploying, so you don't have to administer
two completely different frontends to your Rack app. This already should improve loading times due to
the SPDY architecture. The SPDY server falls back on the plain old HTTP server for processing.

In the future, it will hopefully be possible to reverse the architecture, having a secondary HTTP server
forward requests to the main SPDY server.


Compliance
----------
Momentum is meant to be compliant with this version of the SPDY spec:
http://mbelshe.github.com/SPDY-Specification/draft-mbelshe-spdy-00.xml


Credits
-------
Code parts are borrowed from `https://github.com/romanbsd/spdy`
