class AppConfig < Hash
  include Singleton

  ENV_VARS = %w[
    GITLAB_PROJECT GITLAB_TOKEN GITLAB_ENDPOINT
    SLACK_TOKEN SLACK_CHANNEL
  ]

  def load_file(path)
    path = File.join(File.dirname(__FILE__), '..', '..', path)

    begin
      self.merge!(YAML.load_file(path))
    rescue Errno::ENOENT
      $stdout << "%s not found, using environment variables only\n" % [
        File.basename(path, __FILE__)
      ]
    end

    self
  end

  def import_env
    ENV_VARS.each do |name|
      next unless ENV[name]

      k1, k2 = name.split('_').map(&:downcase).map(&:to_sym)
      self[k1] ||= {}
      self[k1][k2] = ENV[name]
    end

    self
  end

  def define_constants!
    self.each do |k1, v1|
      v1.each do |k2, v2|
        name = [k1, k2].map(&:upcase).join('_')
        AppConfig.const_set(name, v2)
      end
    end
  end
end

AppConfig.instance
  .load_file('config.yaml')
  .import_env
  .define_constants!

begin
  Slack.configure { |c| c.token = AppConfig::SLACK_TOKEN }
rescue NameError
  $stderr << "SLACK_TOKEN not defined, exiting\n"
  exit 1
end
