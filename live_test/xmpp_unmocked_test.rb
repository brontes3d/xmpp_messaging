require 'test/unit'
require 'yaml'
require 'rubygems'
RAILS_ENV = 'test'
require File.dirname(__FILE__) + '/../init'
RAILS_ROOT = File.dirname(__FILE__)

# Jabber::debug = true

class OneListener < XmppMessaging::Listener
  listen_as 'listener1'
  
  def config
    {:hostname => "localhost",
     :users => {
          'listener1' => {
            'login' => 'listener1',
            'password' => 'test'
           }
      },
      :presence_message => "hi"
    }
  end
  
  def on_message(message)
    puts "listener 1 got message size : #{message.body.size}"
  end
  
  
end

class TwoListener < XmppMessaging::Listener
  listen_as 'listener2'
  
  def config
    {:hostname => "localhost",
     :users => {
          'listener2' => {
            'login' => 'listener2',
            'password' => 'test'
           }
      },
      :presence_message => "hi"      
    }
  end
  
  attr_accessor :messages_recieved
  
  def on_message(message)
    @messages_recieved ||= 0
    @messages_recieved += 1
    puts "listener 2 got message : #{message.body}"
  end
  
end

class XmppUnmockedTest < Test::Unit::TestCase
  
  # This test is designed to figure out if we re-send messages when we get disconnected from the server
  # You must setup a jabber server on localhost that accepts connections from listener1 and listener2
  # 
  # The socket is mocked out to return an error on sending the message
  # so the xmpp library is supposed to reconnect the socket and resend the message
  # to pass the test, you should see listener2 echoing that it got a message.
  def test_send_with_disconnect
    
    listener1 = OneListener.new
    listener1.start

    listener2 = TwoListener.new
    listener2.start
    
    fd = listener1.instance_eval{ @connection }.instance_eval{ @fd }

    fd.instance_eval do
      class << self
        def syswrite(str)
          if @did_my_thing_already
            super(str)
          else
            @did_my_thing_already = true
            super("</stream:stream>")
            raise "I'm refusing to let you write #{str} and I'm disconnecting us #{rand}"
          end
        end
      end
    end
    
    #send a message    
    new_message = XmppMessaging::MessageToSend.new
    new_message.body = "test"
    new_message.to = "listener2"
    listener1.send_message(new_message)
    
    while(!listener2.messages_recieved)
      Thread.pass
    end
    assert true, "Passed! we got a message"
  end
  
  def test_upper_limits_of_message_sending
    puts "This test never finishes... it's just going to send itself ever increasingly large messages to test your infratructure"
    
    listener1 = OneListener.new
    listener1.start

    listener2 = TwoListener.new
    listener2.start
    
    Thread.new do
      while(true)     
        new_message = XmppMessaging::MessageToSend.new
        new_message.body = "hi"
        new_message.to = "listener2"
        listener1.send_message(new_message)
        sleep(1)
      end
    end
    
    ever_increasing_write = Base64.encode64(File.read(__FILE__)).gsub("\n", " ")    
    while(true)
      new_message = XmppMessaging::MessageToSend.new
      new_message.body = ever_increasing_write
      new_message.to = "listener1"
      listener2.send_message(new_message)     
      unless ever_increasing_write.size > 10485760
        ever_increasing_write += ever_increasing_write 
      end
    end
    
  end
  
  
end