#!/usr/bin/env ruby
# http://bogojoker.com/readline
require 'readline'
require 'socket'
class Command
    attr_reader :name, :parameters
    attr_accessor :description
    class << self
        attr_accessor :commands
    end
    def self.parse_all
        commands = {}
        command = nil
        ignorees = ["===", "Syntax", "\n", "Defined", "}}", "|"]
        File.open("commands.wikipedia", "r") do |f|
            f.each_line do |line|
                ignored = false
                ignorees.each do |ignore|
                    if line.start_with? ignore  or line.empty?
                        ignored = true
                        break
                    end
                end
                if not ignored
                    if line.start_with? ":<code>" 
                        command = Command.new(line)
                        commands[command.name] = command
                    else command.description = line.split("<ref>")[0]
                    end
                end
            end
        end
        @commands = commands
    end
    def self.help_summary
        puts "| This is a (very) simple didactic client for IRC:",
            "| * type «!» if you need to see this message again",
            "| * First you may wanna issue a «NICK», then a «USER»",
            "| * Autocompletion is available for command names,",
            "|   Prefixing those with #{Mark} will give you a brief help.",
            "| * Response to PING (PONG) is automated, so don't bother.",
            "| * JOIN to join a chan, PRIVMSG to talk"
    end
    def self.help name
        if name.chompt.empty then @help_summary
        else @commands.has_key?(name) ? @commands[name] : name + ": not found"
        end
    end
    def initialize line
        line.chomp!.sub! /:<code><nowiki>(.*)<\/nowiki><\/code>/, '\1'
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
Command.parse_all
Mark = "!"
Readline.completion_append_character = " "
Readline.completion_proc = proc { |s| s.start_with?(Mark) ? \
    Command.get(s[1..-1]).collect! {|x| Mark + x } : Command.get(s)}
stty_save = `stty -g`.chomp
trap('INT') { system('stty', stty_save); exit }
if ARGV.size != 2
    puts "Usage: <server host name> <non encrypted port>"
    exit
end
Command.help_summary
s = TCPSocket.new ARGV[0], ARGV[1]
Thread.new do
    while line = s.gets 
        puts line 
        s.puts "PONG uranus" if line.start_with?("PING ")
    end
end
while line = Readline.readline('', true)
    args = line.split
    if line.start_with? Mark then puts Command.help args[0][1..-1]
    else s.puts line end
end
