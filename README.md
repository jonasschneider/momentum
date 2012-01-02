Momentum, a SPDY Server for Rack apps
=====================================

Momentum is a Rack handler for SPDY clients. That means, it receives connections
from SPDY clients and runs Rack apps. It's that simple.

Additional features are provided by adapters that enable Momentum to act as a proxy to your plain
old HTTP server, or run heavy Rack apps (Rails, I'm looking at you!) in separate threads or processes.


Installation & Usage
--------------------

Add the following to your app's `Gemfile`:

    gem 'momentum', :git => 'git://github.com/jonasschneider/momentum.git', :submodules => true

Then download the code and start the SPDY server by running:

    $ bundle install
    $ bundle exec momentum

The `momentum` command behaves just like `rackup`, it will try to run a `config.ru` file in the 
current directory. Momentum will be started on `0.0.0.0:5555` with the `Defer` adapter (see below).
If you have a recent version of Chrome/Chromium, use the command line flag `--use-spdy=no-ssl` to force
it to use SPDY. Point it at your server, and bam! You're running SPDY.

You can also start Momentum from your code:

    require "momentum"
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ["Hi via SPDY!"]] }
    EM.run {
      Momentum.start(Momentum::Adapters::Defer.new(app))
    }

For more usage examples, see the `examples/` directory.


Backend
-------
As Momentum is Rack-based, the server will deliver all requests to a Rack app.
This Rack app is the argument to `Momentum.start`.
The simplest possible solution is to just use your regular Rack app with the Momentum backend.
SPDY requests to your app will cause your application code to be executed in the SPDY server 
itself.

The Momentum backend provides functionality for deferred/asynchronous responses.
This works just like in a Thin environment: throwing `:async` will cause the
header reply to be postponed. Calling the proc stored in `env['async.callback']`
will send the headers. If you provide a body with callback functionality, you can
even use streaming bodies. [See here for an example from Thin.][thin_async]
Be careful though: when running your app on Momentum, you are probably using an adapter.
While the backend provides `:async` capabilities to the app, not all adapters do.

As your app is most likely not asynchronous, the event loop of the SPDY server will be 
blocked when running your app's code. This can cause timeouts and other problems, and will
effectively make your SPDY sever synchronous.
In order to stay non-blocking, you should use an adapter to offload the app execution to somewhere
else. If you're curious, you can try out what happens without an adapter by running 
`momentum --plain` in your app's directory.


Adapters
--------
Adapters are Rack apps. They can be thought of as middleware. If you do not want your app
to be executed within the SPDY server event loop (i.e. because it blocks), you should use an
adapter. The design of adapters is to return an `:async` response immediately, so the event loop
of the SPDY server is not blocked. Of course, the adapter has to get the real response from somewhere.
The various adapters use mechanisms that are provided by EventMachine to generate or fetch the
response asynchronously.


### Momentum::Adapters::Proxy
The `Proxy` adapter will cause all requests to be forwarded to a given HTTP server.
The SPDY server will act as an HTTP proxy. Advanced features of the SPDY protocol, such as Server
Push, cannot be used, as they would require communication betweeen the backend and the SPDY server
before the response headers is sent.

Internally, `EM::HttpRequest` is used to fetch the resource from the backend.
It is recommended to use a fast backend with this adapter. This means that if your current frontend
uses Thin or Unicorn behind an Nginx proxy, you can point the adapter directly at the backend.

Note that is is _not_ a SPDY/HTTPS proxy for proxying connections to arbitrary servers
through a SPDY tunnel as described in http://dev.chromium.org/spdy/spdy-proxy-examples. It is merely a
way of providing the SPDY protocol to clients without any backend configuration changes.


### Momentum::Adapters::Defer
`Defer` will use the EventMachine thread pool to run your application code. No subprocesses have to be
spawned. Its architecture is very simple, as it does not require any form of inter-process communication.
This reduces overhead in comparison to the `Accelerate` adapter, but also requires your code to be threadsafe.
As it provides the best performance, this adapter is the currently recommended one, and is used by default
when running `momentum`.

Backwards compatibility is important! HTTP clients should be handled by a slave HTTP server that forwards 
requests to the master SPDY server. HTTP support for the SPDY server is a work in progress.


### Momentum::Adapters::Accelerate
`Accelerate` will fork a custom-protocol `Windigo` server that listens on a Unix socket.
Think unicorn, but without the HTTP overhead. In fact the `Windigo` server is a subclass of Unicorn's
HTTP server. The SPDY server will fire incoming requests at that socket.
When a request is received, the backend worker will call your Rack app.
The protocol between the SPDY and the `Windigo` server is custom because besides from regular HTTP 
responses, special SPDY-related messages may be sent back to the SPDY server prior to the response,
such as the request for a SPDY server Push.

Note that this adapter is slower than `Defer` because of the IPC overhead, but allows for non-threadsafe
application code.

Backwards compatibility is important! HTTP clients should be handled by a slave HTTP server that forwards 
requests to the master SPDY server. HTTP support for the SPDY server is a work in progress.


Taking advantage of SPDY Server Push
-------------------------------------
A `Momentum::AppDelegate` object is available in `env['spdy']` when running on Momentum.
The public API for this object currently consists of just one method, `push(url)`.
It should be called when the app can safely determine that the resource
at `path` is going to be required to render the page.

Using it requires the `Accelerate` adapter. If you are not running on it, calling `push` will result 
in a no-op. If you are, calling `push(url)` will initiate a SPDY Server Push to the client.

The SPDY server will be informed of the app's push request, and will start processing the 
request immediately as if was sent as a separate request by the client.

Per the SPDY spec, the virtual request will look to the application completely identical to
the original request, except for the `:host`, `:scheme` and `:path` headers, which contain
the location of the requested resource.


Performance
-----------
I performed somed totally unscientific tests over a local network accessing the example app in
`examples/config.ru` from a media center-style box running Debian. Times were measured 
using the Chrome DOM inspector. The app in question displays a bare-bones HTML page, which 
in turn loads 3 javascripts from the server, each with a size of 100KB. To test SPDY, Chrome
was started with the `--use-spdy=no-ssl` flag, which forces all connections to be SPDY.
This means that SPDY negotiation is not included in the benchmark.
For comparison, a Thin server was started running the same app, accessed by Chrome without
command line arguments.
Traditional benchmark approaches using tools like `ab` are inappropriate because SPDY is not optimized
for raw request benchmarking, but instead focuses on the results given by real browsers.
Besides that, there is no `ab` equivalent for SPDY. High-concurrency benchmarks are still to be done.

This project is in development. The results are, to be honest, horrible.
This is unacceptable given the fact that one of the main goals of SPDY is to improve loading
times, and so performance is a main goal for the Momentum project.
To defend the Momentum results a bit: Thin is a very fast competitor, but is unable to handle 
slow clients gracefully without a reverse proxy in front of it.
Also, the results could have been very different had the test been performed over the internet.
Over a local connection, the advantage of the single connection is negated by the protocol 
overhead, making the multi-connection approach faster.

<table>
  <thead>
    <tr>
      <th>&nbsp;</th>
      <th>Adapters::Accelerate</th>
      <th>Adapters::Defer</th>
      <th>Thin</th>
    </tr>
  </thead>
  
  <tbody>
    <tr>
      <td colspan=4><b>Page components</b></td>
    </tr>
    <tr>
      <td>Initial request, load time of main page</td>
      <td>35ms</td>
      <td>27ms</td>
      <td>8ms</td>
    </tr>
    <tr>
      <td>Subsequent request, load time of main page</td>
      <td>19msms</td>
      <td>15ms</td>
      <td>8ms</td>
    </tr>
    <tr>
      <td>Average load time of the javascripts (100KB)</td>
      <td>150ms</td>
      <td>124ms</td>
      <td>20ms</td>
    </tr>
    <tr>
      <td>Subsequent request, time until javascript is requested</td>
      <td>250ms</td>
      <td>210ms</td>
      <td>180ms</td>
    </tr>

    <tr>
      <td colspan=4><b>Totals</b></td>
    </tr>
    <tr>
      <td>Initial request, time until DOMContentLoaded</td>
      <td>510ms</td>
      <td>450ms</td>
      <td>380ms</td>
    </tr>
    <tr>
      <td>Subsequent request, time until DOMContentLoaded</td>
      <td>460ms</td>
      <td>400ms</td>
      <td>380ms</td>
    </tr>
  </tbody>
</table>


Compliance
----------
Momentum is meant to be compliant with this version of the SPDY spec:
http://mbelshe.github.com/SPDY-Specification/draft-mbelshe-spdy-00.xml


Credits
-------
Thanks to Ilya Grigorik for the great [SPDY parser gem](https://github.com/igrigorik/spdy).
Inspired by Roman Shterenzon's [SPDY server](https://github.com/romanbsd/spdy).
And to https://github.com/inkel/spdy-examples for the sample images ;)

[thin_async]: https://github.com/macournoyer/thin/blob/master/example/async_app.ru