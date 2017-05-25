#!/usr/bin/env LC_ALL=en_US.UTF-8 ruby

# <bitbar.title>Pomodor Tracker</bitbar.title>
# <bitbar.version>v0.1</bitbar.version>
# <bitbar.author>Binoy</bitbar.author>
# <bitbar.author.github>binoymichael</bitbar.author.github>
# <bitbar.desc>A simple pomodor tracker with record history.</bitbar.desc>
# <bitbar.image></bitbar.image>
# <bitbar.dependencies>ruby</bitbar.dependencies>

# Adapted from Ash Wu's Worktime Tracker

def prompt(question, default)
    result = `/usr/bin/osascript -e 'Tell application "System Events" to display dialog "#{question}" default answer "#{default}"' -e 'text returned of result' 2>/dev/null`.strip
    result.empty? ? defult : result
end

def notification(msg, title)
  `/usr/bin/osascript -e 'display notification "#{msg}" with title "#{title}"'`
end

class PomodoroSession
  attr_reader :state, :name
  POMODORO = 60 * 30

  def initialize(name)
    @name = name
    @state = :stopped
    @start_time = nil
  end

  def start
    @start_time = Time.now
    @state = :running
  end

  def stop
    @end_time = Time.now
    @state = :stopped
  end

  def duration
    (@start_time + POMODORO - Time.now).to_i
  end
  
  def to_s
    "#{@name}|#{@start_time}|#{@end_time}"
  end
end

class Pomodoro
  def initialize(workdir = nil)
    @workdir = workdir || File.dirname(__FILE__)
    @session = load_session
  end

  def load_session
    if File.exist? session_file
      Marshal.load(File.read(session_file))
    else
      nil
    end
  end

  def start
    session_name = prompt("Enter session name:", "Unnamed Session")
    @session = PomodoroSession.new session_name
    @session.start
    save_session
  end

  def stop
    @session.stop
    @state = :stopped
    save_session
    save_history
  end

  def save_session
    File.open(session_file, 'w') {|f| f.write(Marshal.dump(@session)) }
  end

  def session_file
    File.join @workdir, ".pomodoro.dat"
  end

  def history_file
    File.join @workdir, "pomodoro", "pomodoro-history.txt"
  end

  def save_history
    system 'mkdir', '-p', File.dirname(history_file)
    File.open(history_file, 'a') { |f| f.write("#{@session}\n") }
  end

  def state
    @session.nil? ? :stopped : @session.state
  end

  def history
    if File.exist? history_file
      system '/usr/bin/open', history_file
    else
      notification("History file not found.", "Pomodoro Tracker")
    end
  end

  def take_a_break
    stop
    `say Take a break`
    `/usr/bin/osascript -e 'tell application "System Events" to tell process "SystemUIServer" to click (first menu item of menu 1 of ((click (first menu bar item whose description is "Keychain menu extra")) of menu bar 1) whose title is "Lock Screen")'`
    start
  end

  def duration
    time_left = @session.duration
    if time_left < 1
      take_a_break
    end
    @session.name + " - " + Time.at(time_left.to_i).utc.strftime("%M:%S") 
  end
end

timer = Pomodoro.new
#
### ACTIONS ###

if ARGV[0]
  action = ARGV[0].to_sym
  if timer.respond_to? action
    timer.send(action)
    exit
  end
end

case timer.state
when :stopped
  TITLE = "Pomodoro"
  MENU = """
Start | bash='#{__FILE__}' param1=start terminal=false
"""
when :running
  TITLE = " #{timer.duration} "
  MENU = """
Stop | bash='#{__FILE__}' param1=stop terminal=false
"""
end

HISTORY = "History | bash='#{__FILE__}' param1=history terminal=false"

puts """
#{TITLE}
---
#{MENU}
---
#{HISTORY}
"""

