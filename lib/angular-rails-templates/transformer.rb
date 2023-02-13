module AngularRailsTemplates
  #
  # Temporary wrapper, old one is deprecated by Sprockets 4.
  #
  class Transformer
    attr_reader :cache_key

    def initialize(options = {})
      @cache_key = [self.class.name, VERSION, options].freeze
    end

    def add_template(ext, template)
      templates[ext] ||= template
    end

    def call(input)
      filename = input[:filename]
      ext      = File.extname(filename).split('.').last

      return input unless has?(ext)

      data     = input[:data]
      context  = input[:environment].context_class.new(input)

      process(filename, data, context, ext)
    end

    private

    def templates
      @templates ||= Hash.new
    end

    def has?(ext)
      templates.has_key?(ext)
    end

    def process(filename, data, context, ext)
      data = templates[ext].new(filename) { data }.render(context, {})
      context.metadata.merge(data: data.to_str)
    end

    class << self
      def instance
        @instance ||= new
      end

      def cache_key
        instance.cache_key
      end

      def call(input)
        instance.call(input)
      end

      def config
        Rails.configuration.angular_templates
      end

      def register(env, ext)
        if ::Sprockets::VERSION.to_i < 4 # Legacy Sprockets
          if ext.eql?('slim')
            klass = Class.new(::Tilt[ext]) do
              def evaluate(scope, locals, &block)
                result = {}

                current_locale = I18n.locale

                I18n.available_locales.each do |loc|
                  I18n.locale = loc
                  result[loc] = super
                end

                I18n.locale = current_locale

                result
              end
            end

            args = [".#{ext}", klass]
            if ::Sprockets::VERSION.to_i == 3
              args << { mime_type: "text/ng-#{ext}", silence_deprecation: true }
            end
            env.register_engine(*args)
          else
            args = [".#{ext}", ::Tilt[ext]]
            if ::Sprockets::VERSION.to_i == 3
              args << { mime_type: "text/ng-#{ext}", silence_deprecation: true }
            end
            env.register_engine(*args)
          end
        else
          instance.add_template(ext, ::Tilt[ext])

          env.register_mime_type   "text/ng-#{ext}", extensions: [".#{config.extension}.#{ext}"]
          env.register_transformer "text/ng-#{ext}", 'text/ng-html', AngularRailsTemplates::Transformer
        end
      end
    end
  end
end
