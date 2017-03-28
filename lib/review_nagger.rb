require 'httparty'
require 'singleton'
require 'slack-ruby-client'

$:.unshift(File.join(File.dirname(__FILE__), 'review_nagger'))
require 'app_config'
require 'client'

Slack.configure do |config|
  config.token = AppConfig::SLACK_TOKEN
end

def jira_handle(title)
  title.match(/([A-Z]*-[0-9]*):/)[1]
rescue
end

def todo_of_type(todo, type)
  todo.select { |t| t[:missing].include?(type) }
end

ICONS = {
  robot: '🤖',
  art: '🎨'
}
