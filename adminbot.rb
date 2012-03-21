require 'cinch'

class Kick
    include Cinch::Plugin
    prefix "."
    match /k ([^ ]+) ?(.*)/
    match /kick ([^ ]+) ?(.*)/
    
    def execute(m, nick, reason)
        if (m.channel.opped? m.user) && (nick.downcase != @bot.nick.downcase)
            m.channel.kick(nick, reason)
        end
    end
end

class KickBan
    include Cinch::Plugin
    prefix "."
    match /kb ([^ ]+) ?(.*)/
    match /unban ([^ ]+)/, method: :unban
    
    def execute(m, nick, reason)
        if (m.channel.opped? m.user) && (nick.downcase != @bot.nick.downcase)
            n = User(nick)
            return if n.unknown
            m.channel.ban("*!*@"+n.host)
            m.channel.kick(n, reason)
        end
    end
    
    def unban(m, nick)
        m.channel.reply User(nick).authname
    end
end


adminbot = Cinch::Bot.new do
    configure do |c|
        c.server = 'irc.freenode.net'
        c.channels = ["#bossko-hii"]
        c.nick = 'kunaldAdminBot'
        c.realname = 'Almost Kunal Desai'
        f = File.new("admin-credentials.txt")
        c.password = f.readline
        f.close
        c.plugins.plugins = [Kick, KickBan]
    end
end

adminbot.start
