class IRC
  def initialize(host, port, user, chan)
    socket = TCPSocket.new(HOST, PORT)
    ssl_context = OpenSSL::SSL::SSLContext.new()
    #ssl_context.cert = OpenSSL::X509::Certificate.new(File.open("certs/MyCompanyClient.crt"))
    #ssl_context.key = OpenSSL::PKey::RSA.new(File.open("keys/MyCompanyClient.key"))

    @ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ssl_context)
    @ssl_socket.sync_close = true
    @ssl_socket.connect
    @user = user
    @chan = chan
    @tasks = []
    @commands = {}
  end

  def send(str)
    @ssl_socket.puts str
  end

  def connect
    send "USER #{@user} #{@user} #{@user} :#{@user} #{@user}"
    send "NICK #{@user}"
    send "JOIN #{@chan}"
  end

  def srv_events(ev)
    case ev.strip
      when /^PING :(.+)$/i
        send "PONG :#{$1}"
      when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]PING (.+)[\001]$/i
        puts "[ CTCP PING from #{$1}!#{$2}@#{$3} ]"
        send "NOTICE #{$1} :\001PING #{$4}\001"
      when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s.+\s:[\001]VERSION[\001]$/i
        puts "[ CTCP VERSION from #{$1}!#{$2}@#{$3} ]"
        send "NOTICE #{$1} :\001VERSION WOLOLO v0.7\001"
      #when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:EVAL (.+)$/i
      #  puts "[ EVAL #{$5} from #{$1}!#{$2}@#{$3} ]"
      #  send "PRIVMSG #{(($4==@user)?$1:$4)} :#{evaluate($5)}"
      when /^:(.+?)!(.+?)@(.+?)\sPRIVMSG\s(.+)\s:(.+)$/i
        puts "[ EVAL #{$5} from #{$1}!#{$2}@#{$3} in #{$4}]"
        evaluate($1, $2, $3, $4, $5)
#        send "PRIVMSG #{(($4==@user)?$1:$4)} :#{evaluate($1, $2, $3, $4, $5)}"
      else
        puts ev
    end
  end

  def evaluate(nick, user, host, chan, text)
    matched = text.match /(#{@user})?[:, ]+(\w*)?/i
    return '' if not matched
    highlighted = matched[1]
    return if not highlighted
    case matched[2].strip
      when /^help$/i
        say "Available commands are: #{@commands.keys.inspect}", :to => ((chan == @user) ? nick : chan)
      else
        if @commands.include?(matched[2].strip)
          @commands[matched[2].strip].call(chan, nick)
        end
    end
  end

  def say(str, params = {})
    params[:to] ||= @chan
    to ||= params[:to]
    str.split("\n").each do |line|
      send "PRIVMSG #{to} :#{line}"
    end
  end

  def command(cmd_name, &block)
    @commands ||= {}
    @commands[cmd_name] = block
  end

  def on_timeout(&block)
    @tasks << block
  end

  def run
    while true
        ready = select([@ssl_socket, $stdin], nil, nil, TIMEOUT)
        if !ready
          @tasks.each do |task|
            task.call
          end
          next
        end
        for s in ready[0]
            if s == $stdin then
                return if $stdin.eof
                s = $stdin.gets
                send s
            elsif s == @ssl_socket then
                return if @ssl_socket.eof
                s = @ssl_socket.gets
                srv_events(s)
            end
        end
     end
  end
end

class Fixnum
  def sec
    self * 1
  end
end

class DSL
  def method_missing(name, *args, &block)
    puts "#{name} called"
  end

  class << self
    def _hear(re)
      "BLABLA #{re}"
    end
  end

  def hear(re, &block)
    @actions ||= []
    @actions << [DSL::_hear(re), block]

    puts "#{re} is an empty action" if not block
    puts "#{re} has associated action"

    p @actions

#    raise "Not implemented"
  end

  def bot_connected
#    raise "Not implemented"
  end

  class Irc
    class Cfg
      attr_accessor :server, :port, :name, :scope
    end

    def initialize
      @cfg = Cfg.new
    end

    def server(s)
      @cfg.server = s
      self
    end

    def port(p)
      @cfg.port = p
      self
    end

    def name(n)
      @cfg.name = n
      self
    end

    def channels(sc, opts = {})
      opts[:scope] ||= nil
      @cfg.scope = sc
      self
    end
  end

  def irc(&block)
    @configs ||= []
    i = Irc.new
    @configs << i.instance_eval(&block)
    p @configs
  end

  def scope(scope_name, &block)
    @scopes ||= {}
    if not @scopes.has_key?(scope_name)
      @scopes[scope_name] = DSL.new
    end

    @scopes[scope_name].instance_eval(&block)
  end

  def configuration(filename = nil, &block)
    puts "LOADING #{filename}" if filename
    block.call if block_given?
  end
end

def irc(&block)
  puts "i can has block" if block
  dsl = DSL.new
  dsl.instance_eval &block
end
