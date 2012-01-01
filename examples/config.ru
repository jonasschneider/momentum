run lambda{ |env|
  if env["PATH_INFO"] == '/'
    env['spdy'].push('/1.js')
    env['spdy'].push('/2.js')
    env['spdy'].push('/3.js')
    body = ["<script src='1.js'></script><script src='2.js'></script><script src='3.js'></script>"]
    tp = 'text/html'
  else
    body = ["a='#{'x'*100_000}'"]
    tp = 'text/javascript'
  end

  [200, {"Content-Type" => tp}, body]
}

#A: 80ms, D: 20ms, T: 3ms