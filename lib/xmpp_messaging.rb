module XmppMessaging
  
  # load config from yaml file (see README for options)
  def self.load_config
    unless @config
      @config = File.open(File.join(RAILS_ROOT,"config","xmpp.yml")) do |fd|
        YAML::load(fd)[RAILS_ENV]
      end
      unless @config
        raise ArgumentError, "no configs found for environment #{RAILS_ENV} in config/xmpp.yml"
      end
      @config.keys.each do |key|
        @config[key.to_sym] = @config[key]
      end
      @config[:port] ||= 5222
      @config[:presence_message] ||= "I'm here"
      @config[:resend_presence_on_recieve] ||= false
      if @config[:debug]
        Jabber::debug = true
      end
      Jabber::debuglog("loaded config " + @config.inspect)
    end
    @config.clone
  end
  
  #An extension of Jabber::Message which adds the 'listener' attribute
  #If you specify a listener, message.from no longer needs to be specified
  class MessageToSend < Jabber::Message
    attr_accessor :listener

    #sends this message. creates a new listener if none is set
    def send
      if listener.nil?
        raise ArgumentError, "Can't send a MessageToSend without a listener"
      else
        listener.send_message(self)
      end
    end
  end
  
  #A wrapper for a received Jabber::Message.
  #
  #Adds 'listener' (a reference to the listener the message was sent from)
  class MessageRecieved
    #you should never be instantiating this class, 
    #when a message is received, one of these will be sent to your listener's +on_message+
    def initialize(jabber_message, xmpp_listener)
      @jabber_message = jabber_message
      @xmpp_listener = xmpp_listener
    end

    #body of the message
    def body
      @jabber_message.body
    end

    #JID from which is was sent
    def from
      @jabber_message.from
    end

    #Listener from which is was received
    def listener
      @xmpp_listener
    end
  end  
  
  class Listener < Jabber::Reliable::Listener
    attr_accessor :jid
    
    def initialize(jid = self.jid)
      @jid = jid
      
      resource = Socket.gethostname.to_s + ":" + Process.pid.to_s
      
      @resend_presence_on_recieve = config[:resend_presence_on_recieve]
      if config[:send_only]
        self.instance_eval do
          class << self
            def send_presence
              Jabber::debuglog "send only listener... refusing to send presence"
            end
          end
        end
      end
      
      super(self.full_jid + "/#{resource}", self.password, self.config) do |msg|
        message_received = XmppMessaging::MessageRecieved.new(msg, self)
        self.on_message(message_received)
        self.after_message_callback
      end
    end
    
    def auth
      @connection.auth_nonsasl(@password, false)      
    end
    
    def connected?
      @connection && @connection.is_connected?
    end

    #Macro to define the JID to use when connecting to the XMPP server
    def self.listen_as(jid)     
      define_method(:jid) do
        @listen_as_jid ||= config[:users][jid.to_s]['login'] rescue "No user named #{jid} found in config: #{config.to_yaml}"
      end
    end
    
    #combine bare_jid with hostname to get complete JID for use in connecting
    def full_jid
      bare_jid+"@"+config[:hostname]
    end
    
    #strip jid into bar JID (before hostname)
    def bare_jid
      jid.split("@")[0]
    end

    # #get password defined in config for defined user
    def password
      return @password if @password
      raise "#{RAILS_ENV} config does not define any users" unless config[:users]
      raise "#{RAILS_ENV} config does not define any users named #{bare_jid}" unless config[:users][bare_jid]
      raise "#{RAILS_ENV} config does not define a password for #{bare_jid}" unless config[:users][bare_jid]['password']
      config[:users][bare_jid]['password']
    end

    # #load the config and return as a hash
    def config
      @config ||= XmppMessaging.load_config
    end
    
    def send_message(message)
      message.from = self.full_jid
      raise "no destination!" unless message.to
      message.to = "#{message.to}@#{config[:hostname]}" unless message.to.to_s.index("@")
      super(message)
    end
    
    #called after each message is processed, will send the presence message again if 
    #+resend_presence_on_recieve+ is set in config
    def after_message_callback
      if @resend_presence_on_recieve
        send_presence
      end
    end    
    
  end
  

end