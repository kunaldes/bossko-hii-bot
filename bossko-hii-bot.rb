require 'cinch'
require 'json'
require 'net/http'

class Seen
    class LeavingStruct < Struct.new(:who, :time)
        def to_s
            t = (Time.now - time).to_i
            day, t = t/86400, t%86400
            hour, t = t/3600, t%3600
            min, t = t/60, t%60
            "#{who} was seen leaving here #{day} days #{hour} hours #{min} minutes and #{t} seconds ago"
        end
    end

    include Cinch::Plugin
    listen_to :part
    listen_to :quit
    match /seen (.+)/

    def initialize(*args)
        super
        @users = {}
    end

    def listen(m)
        @users[m.user.nick.downcase] = LeavingStruct.new(m.user, Time.now)
    end

    def execute(m, nick)
        if nick.split(" ").length > 1
            m.reply "Nicknames can't have spaces"
        elsif nick == @bot.nick
            m.reply "WHAT. I'M RIGHT HERE."
        elsif nick == m.user.nick
            m.reply "Forgetting your nickname, are you?"
        elsif m.channel.users.include? User(nick)
            m.reply "Look a little harder at the channel list..."
        elsif @users.key? nick.downcase
            m.reply @users[nick.downcase].to_s
        else
            m.reply "I haven't seen #{nick}"
        end
    end
end

class Choose
    pick = Proc.new do |msg|
        if msg.message.start_with? "."
            "."
        else
            "!"
        end
    end
    
    include Cinch::Plugin
    match /choose (.+)/
    prefix(pick)

    def execute(m, mesg)
        if mesg.split(",").length > 1
            q = mesg.split(",").map{|x| x.strip}
            m.reply (m.user.to_s + ": " + q[rand(q.length)])
        elsif mesg.split(" ").length > 1
            q = mesg.split(" ").map{|x| x.strip}
            m.reply (m.user.to_s + ": " + q[rand(q.length)])
        else
            m.user.msg "herp derp what 2 choose"
        end
    end
end

class Order
    include Cinch::Plugin
    match /order (.+)/
    prefix "."
    
    def execute(m, mesg)
        if mesg.split(",").length > 1
            q = mesg.split(",").map{|x| x.strip}
            m.reply (m.user.to_s + ": " + q.shuffle!.join(", "))
        elsif mesg.split(" ").length > 1
            q = mesg.split(" ").map{|x| x.strip}
            m.reply (m.user.to_s + ": " + q.shuffle!.join(", "))
        else
            m.user.msg "herp derp what 2 order"
        end
    end
end

class BTC
    class NameMismatchError < StandardError
    end
    
    include Cinch::Plugin
    match /btc (.+)/
    match /btc$/, method: :nonick
    listen_to :private
    
    def initialize(*args)
        super
        @pool_api = {}
        @nick_pool = {}
        f = File.new('btcapis.txt')
        f.each_line do |apiline|
            api = apiline.split(",").map{|x| x.strip}
            @pool_api[api[1]] = api[2]
            @nick_pool[api[0].downcase] = api[1]
        end
    end
    
    def nonick(m)
        if @nick_pool.key? m.user.nick.downcase
            execute(m, @nick_pool[m.user.nick.downcase])
        else
            m.reply "Sorry, I don't know your bitcoin pool API key"
        end
    end
    
    def execute(m, pool_name)
        if not (@pool_api.key? pool_name)
            m.reply "No API key found for #{pool_name}"
        else
            begin
                http = Net::HTTP.new('mining.bitcoin.cz')
                path = '/accounts/profile/json/' + @pool_api[pool_name]
                resp, body = http.get2(path, nil)
                thing = JSON.parse(body)
                m.reply thing["username"] + " has " + 
                    (thing["unconfirmed_reward"].to_f + 
                    thing["confirmed_reward"].to_f).round(8).to_s +
                    " BTC in the mining pool"
            rescue JSON::ParserError
                m.reply "API Key invalidated. Type \"/msg #{@bot.nick} btc_api help\" for instructions"
            end
        end
    end
    
    def listen(m)
        msg = m.message.split(" ").map{|x| x.strip}
        if msg[0] == "btc_api"
            case msg[1].downcase
            when "help"
                m.reply "Usage is /msg #{@bot.nick} btc_api set POOL_USERNAME:API_KEY"
            when "set"
                if msg[2] && msg[2].split(":").length == 2
                    user, key = msg[2].split(":")
                    if @pool_api.key? user && (@nick_pool.key(user) != m.user.nick.downcase)
                        m.reply "That username is not associated with your nickname"
                        return
                    end
                    
                    begin
                        http = Net::HTTP.new('mining.bitcoin.cz')
                        path = '/accounts/profile/json/' + key
                        resp, body = http.get2(path, nil)
                        thing = JSON.parse(body)
                        raise NameMismatchError if thing["username"] != user
                        @pool_api[user] = key
                        @nick_pool[m.user.nick.downcase] = user
                        m.reply "Success! Added the new API key"
                        f = File.new("btcapis.txt", "w")
                        @nick_pool.keys.each do |x|
                            f.write(x + ", " + @nick_pool[x] + ", " + @pool_api[@nick_pool[x]] + "\n")
                        end
                        f.close()
                    rescue JSON::ParserError
                        m.reply "Invalid API key"
                    rescue NameMismatchError
                        m.reply "API key and Username don't match (username is case sensitive)"
                    end
                    
                else
                    m.reply "Incorrect formatting. Type \"/msg #{@bot.nick} btc_api help\" for help"
                end
            else
                m.reply "Correct usage is /msg #{@bot.nick} btc_api set USERNAME:API_KEY"
            end
        end
    end
end


class PokeChoose
    include Cinch::Plugin
    match /choose$/
    
    def initialize(*args)
        super
        pkmn = File.open('pokemon.txt')
        @pokemon = {}
        pkmn.each_line do |pkline|
            pk = pkline.split(",").map{|x| x.strip.upcase}
            @pokemon[pk[0]] = pk[1]
        end
    end
    
    def execute(m)
        poke = @pokemon.keys[rand(@pokemon.keys.length)]
        m.reply "I choose you! #{poke}!"
        m.reply "#{poke} used #{@pokemon[poke]}!"
    end
end

class CTCP_Reply
    include Cinch::Plugin
    listen_to :ctcp
    
    def listen(m)
        if m.ctcp_message.downcase == "version"
            m.ctcp_reply "Cinch IRC Bot version 0.1"
        end
    end
end



bot = Cinch::Bot.new do
    configure do |c|
        c.server   = 'irc.freenode.net'
        c.channels = ["#bossko-hii"]
        c.nick = 'kunaldbot'
        c.plugins.plugins  = [Choose, Order, CTCP_Reply]
    end
end

bot.start
