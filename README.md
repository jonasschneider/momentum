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


Taking advantage of SPDY Server Push
-------------------------------------
A `Momentum::AppDelegate` object is available in `env['spdy']` when running on Momentum.
The public API for this object currently consists of just one method, `push(url)`.
It should be called when the app can safely determine that the resource
at `path` is going to be required to render the page. However, you should not rely on `env['spdy']` being
available, in order to stay compatible to regular Rack servers.

Using it requires the `Defer` adapter. If you are not running on it, calling `push` will result
in a no-op. If you are, calling `push(url)` will initiate a SPDY Server Push to the client.

The SPDY server will be informed of the app's push request, and will start processing the
request immediately as if was sent as a separate request by the client.

Per the SPDY spec, the virtual request will look to the application completely identical to
the original request, except for the `host`, `scheme` and `path` headers (and also `url` to stay compatible
to the current Chromium implementation), which contain the location of the requested resource.


Performance
-----------
This project is in development.
Since one of the main goals of SPDY is to improve loading times, performance is considered vital for Momentum.
I performed somed totally unscientific performance tests. The app in question is located in `examples/lots_of_images.ru`.
It displays a bare-bones HTML page, which in turn loads 100 thumbnail-sized JPEG images from the server.

Loading times were measured using the Chrome DOM inspector, reading the time of the DOMContentLoaded event,
which indicates the arrival of the main HTML document, and the onLoad event, which indicates that all of the
images have been loaded.

To test SPDY, Chrome was started with the `--use-spdy=no-ssl` flag, which forces Chrome to talk SPDY everywhere.
This means that TLS SPDY negotiation is not included in the benchmark. For testing the HTTP servers,
Chrome was started without command-line flags.

The first, smaller group of tests was performed over a local network. The server was running on
a media center-style box under Debian. For the second group of tests, a small Amazon EC2 instance was fired up.

<table>
  <thead>
    <tr>
      <th>&nbsp;</th>
      <th>DOMContentLoaded</th>
      <th>onLoad</th>
    </tr>
  </thead>

  <tbody>
    <tr>
      <td colspan=3><b>LAN connection</b></td>
    </tr>

    <tr>
      <td>WEBrick (for comparison)</td>
      <td>0,2s</td>
      <td>1,5s</td>
    </tr>
    <tr>
      <td>Thin</td>
      <td>0,2s</td>
      <td>0,8ms</td>
    </tr>


    <tr>
      <td colspan=3><b>Internet connection</b></td>
    </tr>

    <tr>
      <td>WEBrick (for comparison)</td>
      <td>0,5s</td>
      <td>4,5s</td>
    </tr>
    <tr>
      <td>Unicorn, 1 worker</td>
      <td>0,6s</td>
      <td>6,5s</td>
    </tr>
    <tr>
      <td>Unicorn, 4 workers</td>
      <td>0,6s</td>
      <td>5,9s</td>
    </tr>
    <tr>
      <td>Unicorn, 4 workers behind nginx</td>
      <td>0,5s</td>
      <td>3,0s</td>
    </tr>
    <tr>
      <td>Thin</td>
      <td>0,5s</td>
      <td>4,5s</td>
    </tr>
    <tr>
      <td>Thin behind nginx</td>
      <td>0,4s</td>
      <td>2,6s</td>
    </tr>

    <tr>
      <td>&nbsp;</td>
      <td>&nbsp;</td>
      <td>&nbsp;</td>
    </tr>

    <tr>
      <td>Momentum/Defer</td>
      <td>0,4s</td>
      <td>2,3s</td>
    </tr>
    <tr>
      <td>Momentum/Defer adapter (subsequent)</td>
      <td>0,3s</td>
      <td>2,1s</td>
    </tr>
    <tr>
      <td>Momentum/Proxy in front of Thin</td>
      <td>0,5s</td>
      <td>2,7s</td>
    </tr>
    <tr>
      <td>Momentum/Proxy in front of Thin (subsequent)</td>
      <td>0,4s</td>
      <td>2,5s</td>
    </tr>
    <tr>
      <td>Momentum/Proxy in front of nginx and Thin</td>
      <td>0,5s</td>
      <td>2,4s</td>
    </tr>
    <tr>
      <td>Momentum/Proxy in front of nginx and Thin (subsequent)</td>
      <td>0,3s</td>
      <td>2,3s</td>
    </tr>
  </tbody>
</table>

Over a local connection, the advantage of the single connection is negated by the protocol
overhead, making the multi-connection approach much faster. Additional tests were therefore ommited.

But over a remote connection, the results look drastically different. As can be seen, the high-performant
servers Thin and Unicorn are meant to be run behind a reverse proxy. There, they achieve great loading times.
Measuring subsequent requests showed that no speedup was gained. Those results are therefore ommited.

The Momentum tests were performed on both initial and subsequent tests to show the improvement caused
by the held SPDY connection. Momentum with the Defer adapter seems to struggle with the high
concurrency caused by the amount of simultaneous requests, but the simplicity of the adapter makes it
faster than the Proxy adapter in front of Thin.

The best results are achieved with the Proxy adapter proxying to nginx, which in turn proxies to Thin.
This is surprising given the overhead of the multiple proxies, but shows the power that lies in the
simple addition of a SPDY server to an established nginx/Thin configuration.

The test may seem biased, as the amount of assets to be loaded is quite high, which favors SPDY.
But, looking at sites such as http://www.nytimes.com/, asset counts in this dimension are quite normal.
For future investigation, different asset file sizes should be considered.
Traditional benchmark approaches using tools like `ab` are deemed inappropriate because SPDY is not optimized
for raw request benchmarking, but instead focuses on the results given by real browsers.
Besides that, there is no `ab` equivalent for SPDY. High-concurrency benchmarks are therefore still to be done,
and are a work in progress.


Compliance
----------
Momentum is meant to be compliant with version 2 of the SPDY spec:
http://www.chromium.org/spdy/spdy-protocol/spdy-protocol-draft2


Credits
-------
Thanks to Ilya Grigorik for the great [SPDY parser gem](https://github.com/igrigorik/spdy).
Inspired by Roman Shterenzon's [SPDY server](https://github.com/romanbsd/spdy).
And to https://github.com/inkel/spdy-examples for the sample images ;)

[thin_async]: https://github.com/macournoyer/thin/blob/master/example/async_app.ru