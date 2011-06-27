require 'cinch'




adminbot = Cinch::Bot.new do
    configure do |c|
        c.server = 'irc.freenode.net'
        c.channels = ["#bossko-hii"]
        c.nick = 'kunaldAdminBot'
        c.realname = 'Almost Kunal Desai'
        f = File.new("admin-credentials.txt")
        c.password = f.readline
        f.close
        c.plugins.plugins = []
    end
end

adminbot.start