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
      end
      
      def prepare(req)
        Reply.new
      end
    end
  end
end