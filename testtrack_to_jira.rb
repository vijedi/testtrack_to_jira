#!/usr/bin/env ruby

require 'rubygems'
gem "soap4r"

require 'jira4r/jira4r'
require 'yaml'
require 'hpricot'

class JiraSoap
    include Jira4R
    
    attr_accessor :endpoint, :user, :password, :project, :assignee, :jira
    
    def initialize(options = {})
        options.each do |key, value|
            self.send(key.to_s+"=", value)
        end
    end
    
    def open
        self.jira = JiraTool.new(2, @endpoint)
        jira.login(@user, @password)
    end
    
    def createIssue(issue)
        issue.project = @project
        issue.type = "1"
        issue.assignee = @assignee
        
        ret_issue = jira.createIssue(issue)
        return ret_issue
    end
    
    def addComment(issue, comment) 
        comment.author = @user
        jira.addComment(issue.key, comment)
    end
end

class JiraImporter
    include Jira4R
    
    attr_accessor :jira, :doc
    
    def initialize(jira, doc)
        self.jira = jira
        self.doc = doc
    end
    
    def import
        (doc/:defect).each do |defect|
            begin
                if((defect/"defect-status").inner_html.downcase.index("open") > -1 )
                    issue = jira.createIssue(create_issue_from_defect(defect))
                
                    comments = []
                    comments.push(create_initial_comment(defect))
                
                    comments.concat(create_histories(defect))
                
                    comments.each do |comment|
                        jira.addComment(issue, comment)
                    end
                end
            rescue
                puts "Unable to parse node: "
                p defect
            end
        end
    end
    
    private
    def create_issue_from_defect(defect)
        issue = V2::RemoteIssue.new
        number = (defect/"defect-number").inner_html
        issue.summary = "TT-#{number} " + (defect/:summary).inner_html
        issue.description = (defect/"reported-by-record"/:description).inner_html
        return issue
    end
    
    def create_initial_comment(defect)
        comment = V2::RemoteComment.new
        
        reporter_node = (defect/"reported-by-record")
        reporter = (reporter_node/"first-name").inner_html + " " + (reporter_node/"last-name").inner_html
        reported_on = (reporter_node/"date-found").inner_html
        disposition = (defect/:disposition).inner_html
        
        comment.body = "Reported by #{reporter} on #{reported_on}.  Effects: #{disposition}"
        
        return comment
    end
    
    def create_histories(defect)
        histories = []
        
        events = (defect/"defect-event")
        events.each do |event|
            author_last_name = (event/"event-author"/"last-name").inner_html
            
            if not author_last_name.empty?
                author_first_name = (event/"event-author"/"first-name").inner_html
                note = (event/:notes).inner_html
                date = (event/"event-date").inner_html
                
                history = V2::RemoteComment.new
                history.body = "On #{date}, #{author_first_name} #{author_last_name} wrote:\n " + note 
                histories.push(history)
            end
        end
        
        return histories
    end
end

class Main
    def Main.run
        properties = YAML.load_file("#{ENV['HOME']}/tt_to_jira.yml")
        export_file = properties.delete('tt_export')
        
        jira = JiraSoap.new( properties )
        jira.open()
        
        doc = Hpricot.XML(open(export_file))
        
        jira_importer = JiraImporter.new(jira, doc)
        jira_importer.import()
    end
end

#######################################
# Run the program
#######################################

Main.run()
