run lambda{ |env|
  if env["PATH_INFO"] == '/'
    body = ''
    Dir['images/*.jpg'].each do |path|
      #env['spdy'].push("/"+path) if env['spdy']
      body << "<img src='#{path}'>"
    end
    body = [body]
    tp = 'text/html'
  else
    path = env["PATH_INFO"][1..-1]
    if File.exist? path
      body = File.open("#{path}")
    else
      puts "could not find #{path}"
      body = []
    end
    tp = 'image/jpeg'
  end

  [200, {"Content-Type" => tp}, body]
}