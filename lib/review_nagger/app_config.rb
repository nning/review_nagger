class AppConfig < Hash
  include Singleton

  def load_file(path)
    path = File.join(File.dirname(__FILE__), '..', '..', path)
    self.merge!(YAML.load_file(path))
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
  .define_constants!
