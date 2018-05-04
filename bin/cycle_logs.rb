#! /usr/bin/env ruby

# roll over all log files every time app is rebooted

require "fileutils"

APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))
Dir.chdir(APP_ROOT)

all_logs = Dir.entries("log").keep_if {|l| !l.start_with?('.')}

# increment each old log by 1
4.downto(1) do |i|
  if i == 4
    all_logs.select {|l| l =~ /#{i}/}.each do |log|
			File.exists?("log/#{log}") ? File.delete("log/#{log}") : next
    end
  else
		all_logs.select {|l| l =~ /#{i}/}.each do |log|
      basename = log.split('.').first
			File.exists?("log/#{basename}.#{i}.log") ? File.rename("log/#{basename}.#{i}.log", "log/#{basename}.#{i + 1}.log") : next
		end
  end
end

# find all logs that haven't been rolled over yet and rename
all_logs.select {|l| l.split('.')[1] == 'log'}.each do |log|
	basename = log.split('.').first
  if File.exists?("log/#{basename}.log")
		FileUtils.cp("log/#{basename}.log", "log/#{basename}.1.log")
		File.delete("log/#{basename}.log")
  end
end


