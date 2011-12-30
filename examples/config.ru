run lambda{ |env| 
  if env["PATH_INFO"] != '/asdf.js'
    body = ["<script src='asdf.js'></script>"]
    tp = 'text/html'
  else
    body = [File.read("application.js")]
    tp = 'text/javascript'
  end
  
  [200, {"Content-Type" => tp}, body]
}