# this is use case

require 'irc'

irc do
  configuration {
    irc {
      server  "irc.freenode.net"
      port    6667
      name    "ircbota"
      channels ["#unlab"], :scope => "s1"
      channels ["#base48"]
    }

    irc {
      server  "anonet"
      port    98734
      name    "trollbota"
      channels ["#hackerspace"]
    }
  }

  #configuration "config.yml"

  scope("s1") {
    hear "wololo" do
      say "#{channel} #{who}"
    end
  }

  bot_connected do
    say "buzny"
  end

  user_connected do
    respond "nazdarek"
    say "yah!"
  end

  user_disconnected do
    say "bululu"
  end

  hear /lal (\d)+/ do |x|
    respond "sam si #{x}"
    say ":D"
  end

  on_idle_timeout do
    say "dako je tu ticho"
  end

  every 13.sec do
    say "aha"
  end

  every 17.sec do
    say "buha"
  end

end
