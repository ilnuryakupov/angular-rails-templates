require 'angular-rails-templates/compact_javascript_escape'

module AngularRailsTemplates
  class Processor

    AngularJsTemplateWrapper = ::Tilt::ERBTemplate.new "#{File.dirname __FILE__}/javascript_template.js.erb"

    include CompactJavaScriptEscape

    def self.instance
      @instance ||= new
    end

    def self.call(input)
      instance.call(input)
    end

    def self.cache_key
      instance.cache_key
    end

    attr_reader :cache_key

    def config
      Rails.configuration.angular_templates
    end

    def initialize(options = {})
      @cache_key = [self.class.name, VERSION, options].freeze
    end

    def template_name(name)
      path = name.sub(/^#{config.ignore_prefix.join('|')}/, '')
      "#{path}.#{config.extension}"
    end

    def localized_template_name(name, locale)
      path = name.sub(/^#{config.ignore_prefix.join('|')}/, '')
      "#{path}-#{locale}.#{config.extension}"
    end

    def call(input)
      file_path = Pathname.new(input[:filename]).relative_path_from(Rails.root).to_s

      unless config.inside_paths.any? { |folder| file_path.match(folder.to_s) }
        return input[:data]
      end

      locals = {}
      locals[:angular_template_name] = template_name(input[:name])
      locals[:angular_module] = config.module_name
      locals[:source_file] = "#{input[:filename]}".sub(/^#{Rails.root}\//,'')

      input[:data].keys.each do |locale|
        locals[:html] ||= {}
        locals[:html][locale] = escape_javascript(input[:data][locale].chomp)

        locals[:angular_template_names] ||= {}
        locals[:angular_template_names][locale] = localized_template_name(scope, locale)
      end

      AngularJsTemplateWrapper.render(nil, locals)
    end
  end
end
