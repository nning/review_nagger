require 'gitlab'
require 'slack-ruby-bot'

CFG = YAML.load_file(File.join(File.dirname(__FILE__), 'config.yaml'))

GITLAB_PROJECT = CFG['gitlab']['project']

GITLAB_API_ENDPOINT = CFG['gitlab']['endpoint']
GITLAB_API_PRIVATE_TOKEN = CFG['gitlab']['token']

SLACK_TOKEN = CFG['slack']['token']

Gitlab.configure do |config|
  config.endpoint = GITLAB_API_ENDPOINT # ENV['GITLAB_API_ENDPOINT']
  config.private_token = GITLAB_API_PRIVATE_TOKEN # ENV['GITLAB_API_PRIVATE_TOKEN']
end

def get_gitlab_project_id
  Gitlab.projects.each do |project|
    hash = project.to_hash

    if hash['namespace']['name'] == GITLAB_PROJECT
      return hash['id']
    end
  end
end

GITLAB_PROJECT_ID = get_gitlab_project_id

# tmp = Gitlab.merge_requests(GITLAB_PROJECT_ID).select do |mr|
#   mr.iid == 362
# end

# p Gitlab.merge_request_comments(GITLAB_PROJECT_ID, tmp.first.id)

# class ReviewNagger < SlackRubyBot::Bot
#   command 'ping' do |client, data, match|
#     client.say(text: 'pong', channel: data.channel)
#   end
# end

# ReviewNagger.run
