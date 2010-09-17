require 'test/unit'
require 'yaml'
require 'rubygems'
RAILS_ENV = 'test'
require File.dirname(__FILE__) + '/../init'
require File.dirname(__FILE__) + '/mock_listener'
RAILS_ROOT = File.dirname(__FILE__)

class Test::Unit::TestCase
  def logger
    RAILS_DEFAULT_LOGGER
  end
end

def wait_for(options = {:timeout => 5})
  sleep_each_retry = options[:sleep_interval] || 0.1
  retry_count = options[:timeout] / sleep_each_retry
  while(retry_count > 0)
    return if(yield)
    retry_count -= 1
    sleep(sleep_each_retry)
  end
  flunk("timed out")
end