#!/usr/bin/env ruby

require 'rubygems'
gem "soap4r"

require 'jira4r/jira4r'
require 'yaml'

class JiraSoap
    include Jira4R
    
    attr_accessor :endpoint, :user, :password, :project, :assignee
    
    def initialize(options = {})
        options.each do |key, value|
            self.send(key.to_s+"=", value)
        end
    end
    
end

class Main
    def Main.run
        properties = YAML.load_file("#{ENV['HOME']}/tt_to_jira.yml")
        export_file = properties.delete('tt_export')
        jira = JiraSoap.new( properties )
    end
end

#######################################
# Run the program
#######################################

Main.run()
