require 'rubygems'
require 'open-uri'
require 'nokogiri'

require 'socket'
require 'openssl'

HOST = ''
PORT = 6667
USER = 'hbot'
CHAN = '#chan'

TIMEOUT = 10 #in seconds

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
      when /^PING:(.+)$/i
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

irc = IRC.new(HOST, PORT, USER, CHAN)
irc.connect()

irc.on_timeout do
  site = ''

  html = Nokogiri::HTML(open(''))
  list = html.css('form#dw__recent > div > ul > li > div')
  
  recent = open('recent', 'r')
  r = recent.read.split "\n"

  recent = open('recent', 'a')
  to_say = list.each do |item| 
    date = item.css('span.date').text.strip
    href = item.css('a.wikilink1').attr('href')
    sum  = item.css('span.sum').text
    user = item.css('span.user').text.strip
    if !r.include?(date.strip)
      irc.say "WEB NEWS: #{date} \nAt #{site}#{href}\nBy:#{user}\nSummary:#{sum}"
      recent.puts date
    end
  end
  recent.close
end

irc.command "mostrecent" do |chan, from|
  to = chan
  to = from if chan == USER

  site = ''

  html = Nokogiri::HTML(open(''))
  list = html.css('form#dw__recent > div > ul > li > div')

  item = list[0]
  date = item.css('span.date').text.strip
  href = item.css('a.wikilink1').attr('href')
  sum  = item.css('span.sum').text
  user = item.css('span.user').text.strip

  irc.say "WEB NEWS: #{date}\n#{site}#{href}\nBy: #{user}\nSummary: #{sum}", :to => to
end

irc.command "ping" do |chan, from|
  to = chan
  to = from if chan == USER
  irc.say "pong", :to => to
end

begin
    irc.run()
rescue Interrupt
rescue Exception => detail
    puts detail.message()
    print detail.backtrace.join("\n")
    retry
end