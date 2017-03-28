class Nagger
  ICONS = { robot: '🤖', art: '🎨' }

  def initialize
    @gitlab = Client.new

    @slack = Slack::Web::Client.new
    @slack.auth_test
  end

  def run!
    todo = get_todo(get_merge_requests)
    notify_slack!(todo)
  end

  def get_merge_requests
    merge_requests = @gitlab.filtered_merge_requests
    raise if !merge_requests || !merge_requests.any?
    merge_requests
  end

  def jira_handle(title)
    title.match(/([A-Z]*-[0-9]*):/)[1]
  rescue
  end

  def get_todo(merge_requests)
    todo = []

    merge_requests.each do |merge_request|
      todo << {
        title: merge_request['title'],
        url: merge_request['web_url'],
        missing: @gitlab.missing_reviews(merge_request),
        jira: jira_handle(merge_request['title'])
      }
    end

    todo
  end

  def todo_of_type(todo, type)
    todo.select { |t| t[:missing].include?(type) }
  end

  def format_todo(todo)
    todo.map { |t| t[:url] + ' (%s)' % t[:jira] }.join($/)
  end

  def notify_slack!(todo)
    message = '@channel *TODOs*'

    ['robot', 'art'].each do |type|
      next unless todo_of_type(todo, type).any?

      message << $/ + ICONS[type.to_sym] + $/
      message << format_todo(todo_of_type(todo, type))
    end

    AppConfig::SLACK_CHANNELS.each do |channel|
      @slack.chat_postMessage \
        channel: '#%s' % channel,
        text: message,
        as_user: true,
        parse: 'full'
    end
  end
end
