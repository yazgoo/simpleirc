#!/usr/bin/env ruby
# http://bogojoker.com/readline
require 'readline'
require 'socket'
require 'net/http'
class String
    def tohtml!
        gsub! "&lt;", "<"
        gsub! "&gt;", ">"
    end
end
class Command
    CACHE_PATH = "commands.wikipedia"
    attr_reader :name, :parameters
    attr_accessor :description
    class << self
        attr_accessor :commands, :port
    end
    def self.download
        return if File.exists? CACHE_PATH
        Net::HTTP.start("en.wikipedia.org") do |http|
            resp = http.get("/wiki/Special:Export/List_of_Internet_Relay_Chat_commands",
                            {
                             'Referer' => 'http://gitorious.org/simpleirc',
                             'User-Agent' => 'simpleirc'
                            })
            open(CACHE_PATH, "wb") do |file|
                file.write(resp.body)
            end
        end
    end
    def self.parse_all
        commands = {}
        command = nil
        running = false
        start_symbol = "==User commands=="
        ignorees = ["===", "Syntax", "\n", "Defined",
            "}}", "|", "</mediawiki>", start_symbol]
        File.open("commands.wikipedia", "r") do |f|
            f.each_line do |line|
                break if line.start_with? "==See also=="
                running = true if line.start_with? start_symbol
                next if not running
                ignored = false
                ignorees.each do |ignore|
                    if line.start_with? ignore  or line.empty?
                        ignored = true
                        break
                    end
                end
                if not ignored
                    if line.start_with? ":&lt;code&gt;" 
                        command = Command.new(line)
                        commands[command.name] = command
                    else (command.description = line.split("&lt;ref&gt;")[0]).tohtml!
                    end
                end
            end
        end
        @commands = commands
    end
    def self.help_summary
        <<eos
This is a (very) simple didactic client for IRC:
* «telnet localhost #{@port}» in another tty to get output
* type «!» if you need to see this message again
* First you may wanna issue a «NICK», then a «USER»
* Autocompletion is available for command names,
  Prefixing those with #{Mark} will give you a brief help.
* Response to PING (PONG) is automated, so don't bother.
* JOIN to join a chan, PRIVMSG to talk
eos
    end
    def self.help name
        if name.chomp.empty? then help_summary
        else @commands.has_key?(name) ? @commands[name] : name + ": not found"
        end
    end
    def tohtml str
        str.gsub("&lt;", "<").gsub "&gt;", ">"
    end
    def initialize line
        line.chomp!.sub! /:&lt;code&gt;&lt;nowiki&gt;(.*)&lt;\/nowiki&gt;&lt;\/code&gt;/, '\1'
        line.tohtml!
        @parameters = line.split
        @name = @parameters.delete_at 0
    end
    def to_s
        @parameters.join(" ") + "\n" + @description
    end
    def self.get s
        Command.commands.keys.grep( /^#{Regexp.escape(s)}/ )
    end
end
Mark = "!"
stty_save = `stty -g`.chomp
trap('INT') { system('stty', stty_save); exit }
irc_port = 6651
Command.port = 2000
if ARGV.size < 1
    puts "Usage: <server host name> [<non encrypted port=#{irc_port}> [<command port=#{Command.port}>]]"
    exit
end
irc_port = ARGV[1].to_i if ARGV.size > 1
Command.port = ARGV[2].to_i if ARGV.size > 2
Command.download
Command.parse_all
Readline.completion_append_character = " "
Readline.completion_proc = proc { |s| s.start_with?(Mark) ? \
    Command.get(s[1..-1]).collect! {|x| Mark + x } : Command.get(s)}
puts Command.help_summary
TCPSocket.open(ARGV[0], ARGV[1]) do |s|
    Thread.new do
        TCPServer.open Command.port do |server|
            loop do
                client = server.accept
                client.puts "welcome"
                while line = s.gets 
                    client.puts line
                    s.puts "PONG uranus" if line.start_with?("PING ")
                end
                client.close
            end
        end
    end
    while line = Readline.readline('> ', true)
        args = line.split
        if line.start_with? Mark then puts Command.help args[0][1..-1]
        else s.puts line end
    end
end
