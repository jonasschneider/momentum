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

    Momentum.start(rack_app_)

Credits
-------
Code parts are borrowed from `https://github.com/romanbsd/spdy`