require 'httparty'
require 'singleton'
require 'slack-ruby-client'

class AppConfig < Hash
  include Singleton

  def load_file(path)
    self.merge!(YAML.load_file(File.join(File.dirname(__FILE__), path)))
    self
  end

  def define_constants!
    self.each do |k1, v1|
      v1.each do |k2, v2|
        name = [k1, k2].map(&:upcase).join('_')
        Object.const_set(name, v2)
      end
    end
  end
end

cfg = AppConfig.instance.load_file('config.yaml')
cfg.define_constants!

Slack.configure do |config|
  config.token = SLACK_TOKEN
end

class Client
  include HTTParty
  base_uri GITLAB_ENDPOINT

  OPTIONS = {
    headers: {
      'PRIVATE-TOKEN': GITLAB_TOKEN
    }
  }

  def merge_requests
    self.class
      .get('/projects/%s/merge_requests' % project_id, OPTIONS)
      .parsed_response
  end

  def labels_include?(labels, needle)
    labels.select { |label| label.starts_with?(needle) }.any?
  end

  def integration?(merge_request)
    labels_include?(merge_request['labels'], 'integration')
  end

  def stalled?(merge_request)
    labels_include?(merge_request['labels'], 'stalled')
  end

  def review?(merge_request)
    labels_include?(merge_request['labels'], 'interne review')
  end

  def wip?(merge_request)
    labels_include?(merge_request['labels'], 'wip')
  end

  def filtered_merge_requests
    merge_requests.select do |merge_request|
      votes = integration?(merge_request) ? 1 : 2

      # Above upvote threshold
      x = merge_request['upvotes'] < votes

      # Not work in progress
      x = x && !merge_request['work_in_progress']
      x = x && !wip?(merge_request)

      # Not stalled
      x = x && !stalled?(merge_request)

      # In review
      x = x && review?(merge_request)

      # Not already merged
      x = x && merge_request['status'] != 'merged'

      x
    end
  end

  def awards(merge_request)
    self.class
      .get('/projects/%s/merge_requests/%s/award_emoji' % [project_id, merge_request['iid']], OPTIONS)
      .parsed_response
  end

  def has_award?(awards, name)
    awards.select { |award| award['name'] == name }.any?
  end

  def missing_reviews(merge_request)
    awards = awards(merge_request)
    ['robot', 'art'].select { |type| !has_award?(awards, type) }
  end

  def project_id
    @project_iid ||= begin
      projects = self.class.get('/projects', OPTIONS).parsed_response

      projects.each do |project|
        if project['namespace']['name'] == GITLAB_PROJECT
          return project['id']
        end
      end
    end
  end
end

def jira_handle(title)
  title.match(/([A-Z]*-[0-9]*):/)[1]
rescue
end

def todo_of_type(todo, type)
  todo.select { |t| t[:missing].include?(type) }
end

todo = []
icons = {
  robot: '🤖',
  art: '🎨'
}

client = Client.new
merge_requests = client.filtered_merge_requests

exit if !merge_requests || !merge_requests.any?

merge_requests.each do |merge_request|
  todo << {
    title: merge_request['title'],
    url: merge_request['web_url'],
    missing: client.missing_reviews(merge_request),
    jira: jira_handle(merge_request['title'])
  }
end

slack = Slack::Web::Client.new
slack.auth_test

message = "*TODOs*"

['robot', 'art'].each do |type|
  next unless todo_of_type(todo, type).any?

  message << "\n" + icons[type.to_sym] + "\n"
  message << todo_of_type(todo, type)
    .map { |t| t[:url] + ' (%s)' % t[:jira] }.join("\n")
end

SLACK_CHANNELS.each do |channel|
  slack.chat_postMessage(channel: '#%s' % channel, text: message)
end
