require 'xmpp4r'
# require File.join(File.dirname(__FILE__), "..", "..", "xmpp4r", "lib", "xmpp4r.rb")

$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'xmpp_messaging'

if(defined?(MOCK_OUT_JABBER_SERVER) && MOCK_OUT_JABBER_SERVER == true)
  Jabber::Test::ListenerMocker.mock_out_all_connections
end

if(defined?(JABBER_WARNINGS_OUTPUT_HANDLER))
  Jabber.module_eval do
    def Jabber::warnlog(string)
      JABBER_WARNINGS_OUTPUT_HANDLER.call(string)
    end    
  end
end

if(defined?(JABBER_DEBUG_OUTPUT_HANDLER))
  Jabber.module_eval do
    def Jabber::debuglog(string)
      return if not Jabber::debug
      JABBER_WARNINGS_OUTPUT_HANDLER.call(string)
    end    
  end  
end