class GitLab
  include HTTParty
  base_uri AppConfig::GITLAB_ENDPOINT

  OPTIONS = {
    headers: {
      'PRIVATE-TOKEN': AppConfig::GITLAB_TOKEN
    }
  }

  def merge_requests
    path = '/projects/%s/merge_requests?state=%s&per_page=%s' % [
      project_id,
      :opened,
      100
    ]

    self.class.get(path, OPTIONS).parsed_response
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

  def code_review_only?(merge_request)
    labels_include?(merge_request['labels'], 'code review only')
  end

  def necessary_votes(merge_request)
    code_review_only?(merge_request) ? 1 : 2
  end

  def filtered_merge_requests
    merge_requests.select do |merge_request|
      # Above upvote threshold
      x = merge_request['upvotes'] < necessary_votes(merge_request)

      # Not work in progress
      x &&= !merge_request['work_in_progress']
      x &&= !wip?(merge_request)

      # Not stalled
      x &&= !stalled?(merge_request)

      # In review
      x &&= review?(merge_request)

      x
    end
  end

  def awards(merge_request)
    path = '/projects/%s/merge_requests/%s/award_emoji' % [
      project_id,
      merge_request['iid']
    ]

    self.class.get(path, OPTIONS).parsed_response
  end

  def has_award?(awards, name)
    awards.select { |award| award['name'] == name }.any?
  end

  def missing_reviews(merge_request)
    %w[robot art].select do |type|
      # Type has no awards
      x = !has_award?(awards(merge_request), type)

      # If type is art, review is missing, if more than 1 vote necessary
      if type == 'art'
        x &&= necessary_votes(merge_request) > 1
      end

      x
    end
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
