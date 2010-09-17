require File.dirname(__FILE__) + '/test_helper'

class XmppMessagingTest < Test::Unit::TestCase
  def setup
    @test_message_contents = "this is a message"
  end
  
  def teardown
    if @i_setup_connect_override
      Jabber::Client.class_eval do
        alias connect connect_original
      end
      @i_setup_connect_override = false
    end
  end
  
  def test_resend_presence_on_recieve
    mock_listener = MockListener1.new
    MockListener1.class_eval do
      attr_accessor :connection
    end
    @@sent_calls_made = []
    
    mock_listener.connection.instance_eval do
      class << self
        alias original_send send
        def send(xml, &block)
          @@sent_calls_made << xml
          original_send(xml, &block)
        end
      end
    end
    
    mock_listener.start
    
    mock_listener2 = MockListener2.new
    mock_listener2.start
  
    assert_equal(0, mock_listener.messages_received.size)
    
    message = XmppMessaging::MessageToSend.new
    message.listener = mock_listener2
    message.to = 'app1'
    message.body = @test_message_contents
    message.send
    
    assert_equal(1, mock_listener.messages_received.size)
        
    assert_equal(2, @@sent_calls_made.size, "Expected 2 presences to have been sent by now but got " + 
                                              @@sent_calls_made.collect(&:to_s).inspect)
    
    assert_equal("<presence xmlns='jabber:client'><show>chat</show><status>one message at a time</status></presence>",
                  @@sent_calls_made[0].to_s)

    assert_equal("<presence xmlns='jabber:client'><show>chat</show><status>one message at a time</status></presence>",
                  @@sent_calls_made[1].to_s)
                  
    mock_listener.stop
    mock_listener2.stop
  end
  
  def test_send_only
    mock_listener = SendOnlyListener.new
    SendOnlyListener.class_eval do
      attr_accessor :connection
    end
    @@sent_calls_made = []
    
    mock_listener.connection.instance_eval do
      class << self
        alias original_send send
        def send(xml, &block)
          @@sent_calls_made << xml
          original_send(xml, &block)
        end
      end
    end
    
    mock_listener.start
    
    mock_listener2 = MockListener2.new
    mock_listener2.start
  
    assert_equal(0, mock_listener.messages_received.size)
    
    message = XmppMessaging::MessageToSend.new
    message.listener = mock_listener2
    message.to = 'app1'
    message.body = @test_message_contents
    message.send
    
    assert_equal(1, mock_listener.messages_received.size)
        
    assert_equal(0, @@sent_calls_made.size, "Expected 0 presences to have been sent by now but got " + 
                                              @@sent_calls_made.collect(&:to_s).inspect)    

    mock_listener.stop
    mock_listener2.stop
  end
  
  def test_presence_sent_on_connect
    mock_listener = MockListener1.new
    MockListener1.class_eval do
      attr_accessor :connection
    end
    @@sent_calls_made = []
    
    mock_listener.connection.instance_eval do
      class << self
        alias original_send send
        def send(xml, &block)
          @@sent_calls_made << xml
          original_send(xml, &block)
        end
      end
    end
    
    mock_listener.start
    
    assert_equal("<presence xmlns='jabber:client'><show>chat</show><status>one message at a time</status></presence>",
                  @@sent_calls_made[0].to_s)
    
    message = XmppMessaging::MessageToSend.new
    message.to = 'app1'
    message.body = @test_message_contents
    mock_listener.send_message(message)
    
    assert @@sent_calls_made[1].is_a?(XmppMessaging::MessageToSend), 
          "Expected a XmppMessaging::MessageToSend in #{@@sent_calls_made[1].class.inspect}"
          
    assert_equal(@test_message_contents, @@sent_calls_made[1].body)
    
    mock_listener.stop
  end
  
  def test_reliable_connect_exceptions
    @i_setup_connect_override = true
    Jabber::Client.class_eval do
      alias connect_original connect      
      def connect(host = nil, port = 5222)
        Jabber::debuglog("reliable connection exception test is raising")
        @@times_raised += 1;
        raise ExceptionClassJustForThisTest, "something is wrong bla bla"
      end
    end
    
    eval %Q{
      class ExceptionClassJustForThisTest < RuntimeError
      end
    }
    
    @@times_raised = 0
    
    assert_raises(ExceptionClassJustForThisTest) do
      connection = Jabber::Reliable::Listener.new("listener1@localhost","password",{
        :servers => ["127.0.0.101","127.0.0.102","127.0.0.103","127.0.0.104","127.0.0.105"],
        :max_retry => 10,
        :retry_sleep => 0.1 
        })
      connection.connect
    end
    
    assert_equal(11, @@times_raised, "Since max retry was set to 10, we should have raised 11 times (1 initial + 10 retrys)")
  end
  
  def test_reliable_connect_timeout
    @i_setup_connect_override = true
    Jabber::Client.class_eval do
      alias connect_original connect      
      def connect(host = nil, port = 5222)
        Jabber::debuglog("reliable connection test is trying to sleep forever in this test")
        @@connection_attempts_by_server[host] ||= 0
        @@connection_attempts_by_server[host] += 1
        @@times_connection_attempted += 1
        while(true)
          sleep(1)
        end
      end
    end
    
    @@connection_attempts_by_server = {}
    servers = ["127.0.0.101","127.0.0.102","127.0.0.103","127.0.0.104","127.0.0.105"]
    
    @@times_connection_attempted = 0
        
    assert_raises(Timeout::Error) do
      connection = Jabber::Reliable::Listener.new("listener1@localhost","password",{
        :servers => servers,
        :max_retry => 35, #adds up to 7 retries for each of the 5 servers
        :retry_sleep => 0.05
        })
      connection.connect
    end
    
    servers.each do |server|
      attempts = @@connection_attempts_by_server[server]
      assert( (attempts == 7) || (attempts == 8), 
        "Connection attempts for server #{server} should be 7 or 8 (7 retries), but was: #{attempts}")
    end
    
    assert_equal(36, @@times_connection_attempted, 
      "Since max retry was set to 7 and there are 5 possible servers, "+
        "we should have attempted to connect 36 times (1 initial + (7 retrys * 5 servers))." + 
        "actual result: " + @@connection_attempts_by_server.inspect)
  end
  
  # Jabber::debug = true
  
  def test_message_send    
    mock_listener1 = MockListener1.new
    mock_listener1.start

    mock_listener2 = MockListener2.new
    mock_listener2.start
  
    assert_equal(0, mock_listener1.messages_received.size)
    
    message = XmppMessaging::MessageToSend.new
    message.listener = mock_listener2
    message.to = 'app1'
    message.body = @test_message_contents
    message.send
    
    wait_for{ mock_listener1.messages_received.size > 0 }
    
    assert_equal(1, mock_listener1.messages_received.size)  
    assert_equal(@test_message_contents, mock_listener1.messages_received[0].body)
    
    mock_listener1.stop
    mock_listener2.stop
  end
    
  # test config loading
  
  # test ReliableConnection reliable_connect (servers, max_retry, retry_sleep)  
  
  # test situations where we might try to send while disconnected
  
  # test resend_presence_on_recieve
  
  # test send_only  
  
end