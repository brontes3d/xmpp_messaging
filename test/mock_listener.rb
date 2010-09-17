class MockListener < XmppMessaging::Listener
    
  def on_message(message)
    self.messages_received << message
  end
  
  def messages_received
    @messages_received ||= []
  end
  
  def initialize
    super
    Jabber::Test::ListenerMocker.mock_out(self)
  end
  
end

class MockListener1 < MockListener
  
  listen_as 'app1'
    
end

class MockListener2 < MockListener
  
  listen_as 'app2'
  
end

class SendOnlyListener < MockListener1
  
  def initialize
    self.config[:send_only] = true
    super
  end
  
end