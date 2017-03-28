class Client
  include HTTParty
  base_uri AppConfig::GITLAB_ENDPOINT

  OPTIONS = {
    headers: {
      'PRIVATE-TOKEN': AppConfig::GITLAB_TOKEN
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
        if project['namespace']['name'] == AppConfig::GITLAB_PROJECT
          return project['id']
        end
      end
    end
  end
end
