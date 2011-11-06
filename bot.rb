require 'rubygems'
require 'open-uri'
require 'nokogiri'

require 'socket'
require 'openssl'
require 'yaml'

$cfg = YAML::load_file('config.yml')

HOST = $cfg['irc']['host']
PORT = $cfg['irc']['port']
USER = $cfg['irc']['user']
CHAN = $cfg['irc']['chan']

TIMEOUT = $cfg['timeout']

require 'irc'

def scan(type, irc, say_to)
  #type:
  #  :changes
  #  :most_recent
  #  :all

  site = $cfg['web']['site']
  dw_recent = File.join(site, $cfg['web']['dw_recent'])

  html = Nokogiri::HTML(open(dw_recent))
  list = html.css('form#dw__recent > div > ul > li > div')

  case type
    when :changes
      recent = open('recent', 'r')
      r = recent.read.split "\n"

      recent = open('recent', 'a')
    when :most_recent
      l = list[0]
      list = []
      list << l
  end


  list.each do |item|
    begin
      date = item.css('span.date').text.strip
    rescue
      date = nil
    end
    begin
      href = item.css('a.wikilink1').attr('href').value.strip
    rescue
      href = nil
    end
    begin
      sum = item.css('span.sum').text.strip
    rescue
      sum = nil
    end
    begin
      user = item.css('span.user').text.strip
    rescue
      user = nil
    end
    formatted = "WEB NEWS: #{date} | #{user} | #{sum}\nurl: #{site}#{href}"

    if (type == :changes) && (!r.include?(date.strip))
      irc.say formatted, :to => say_to
      recent.puts date
    elsif [:most_recent, :all].include?(type)
      irc.say formatted, :to => say_to
    end
  end

  recent.close if type == :changes
end

irc = IRC.new(HOST, PORT, USER, CHAN)
irc.connect()

irc.on_timeout do
  scan(:changes, irc, CHAN)
end

irc.command "mostrecent" do |chan, from|
  to = chan
  to = from if chan == USER

  scan(:most_recent, irc, to)
end

irc.command "everything" do |chan, from|
  to = chan
  to = from if chan == USER

  scan(:all, irc, to)
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
