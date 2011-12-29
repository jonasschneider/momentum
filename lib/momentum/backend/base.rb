module Momentum
  module Backend
    class Base
      class Reply
        def on_headers(&blk)
          @on_headers = blk
        end
        
        def on_body(&blk)
          @on_body = blk
        end
        
        def on_complete(&blk)
          @on_complete = blk
        end
        
        def dispatch!
          
        end

        protected
        
        def cleanup_headers(headers)
          hdrs = headers.inject(Hash.new) do |hash,kv|
            hash[kv[0].downcase.gsub('_', '-')] = kv[1]
            hash
          end
          #hdrs.http_reason = headers.http_reason
          #hdrs.http_status = headers.http_status
          #if cookie = hdrs['Set-Cookie'] and cookie.respond_to?(:join)
          #  hdrs['Set-Cookie'] = cookie.join(', ')
          #end
          hdrs.each {|k,v| hdrs[k] = v.first if v.respond_to?(:first)}
          # Remove junk headers
          hdrs.reject! {|hdr| hdr.start_with?('X-')}
          hdrs.reject! {|hdr| REJECTED_HEADERS.include? hdr}
          hdrs.reject! {|hdr,val| val.empty?}
          hdrs
        end
      end
      
      def prepare(req)
        Reply.new
      end
    end
  end
end