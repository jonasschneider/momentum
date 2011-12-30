run lambda{ |env| 
  if env["PATH_INFO"] != '/asdf.js'
    body = ["<script src='asdf.js'></script>"]
    tp = 'text/html'
  else
    body = ["a='#{'x'*100_000}'"]
    tp = 'text/javascript'
  end
  
  [200, {"Content-Type" => tp}, body]
}