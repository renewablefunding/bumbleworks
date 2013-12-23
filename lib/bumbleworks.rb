require "forwardable"
require "bumbleworks/version"
require "bumbleworks/configuration"
require "bumbleworks/support"
require "bumbleworks/process_definition"
require "bumbleworks/process"
require "bumbleworks/task"
require "bumbleworks/participant_registration"
require "bumbleworks/ruote"
require "bumbleworks/hash_storage"
require "bumbleworks/error_handler"
require "bumbleworks/entity"
require "bumbleworks/participant"
require "bumbleworks/workitem"

# default implementations
require "bumbleworks/simple_logger"
require "bumbleworks/error_logger"

module Bumbleworks
  class UnsupportedMode < StandardError; end
  class UndefinedSetting < StandardError; end
  class InvalidSetting < StandardError; end
  class InvalidEntity < StandardError; end
  class EntityNotFound < StandardError; end

  class << self
    extend Forwardable

    Configuration.defined_settings.each do |setting|
      def_delegators :configuration, setting, "#{setting.to_s}="
    end

    def_delegators Bumbleworks::Ruote,
      :dashboard, :start_worker!,
      :cancel_process!, :kill_process!,
      :cancel_all_processes!, :kill_all_processes!
    def_delegator Bumbleworks::ProcessDefinition, :define, :define_process

    # @public
    # Returns the global configuration, or initializes a new configuration
    # object if it doesn't exist yet.  If initializing new config, also adds
    # default storage adapters.
    #
    def configuration
      @configuration ||= begin
        configuration = Bumbleworks::Configuration.new
        configuration.add_storage_adapter(Bumbleworks::HashStorage)
        if defined?(Bumbleworks::Redis::Adapter) && Bumbleworks::Redis::Adapter.auto_register?
          configuration.add_storage_adapter(Bumbleworks::Redis::Adapter)
        end
        if defined?(Bumbleworks::Sequel::Adapter) && Bumbleworks::Sequel::Adapter.auto_register?
          configuration.add_storage_adapter(Bumbleworks::Sequel::Adapter)
        end
        configuration
      end
    end

    # @public
    # Return true only if store_history (from configuration) is true.
    #
    def store_history?
      configuration.store_history == true
    end

    # @public
    # Yields the global configuration to a block.
    # @yield [configuration] global configuration
    #
    # @example
    #   Bumbleworks.configure do |c|
    #     c.root = 'path/to/ruote/assets'
    #   end
    # @see Bumbleworks::Configuration
    def configure(&block)
      unless block
        raise ArgumentError.new("You tried to .configure without a block!")
      end
      yield configuration
    end

    # @public
    # Same as .configure, but clears all existing configuration
    # settings first.
    # @yield [configuration] global configuration
    # @see Bumbleworks.configure
    def configure!(&block)
      @configuration = nil
      configure(&block)
    end

    # @public
    # Accepts a block for registering participants.  Note that a
    # 'catchall Ruote::StorageParticipant' is always added to
    # the end of the list (unless it is defined in the block).
    #
    # @example
    #   Bumbleworks.register_participants do
    #     painter PainterClass
    #     builder BuilderClass
    #     plumber PlumberClass
    #   end
    def register_participants(&block)
      Bumbleworks::ParticipantRegistration.autoload_all
      Bumbleworks::Ruote.register_participants(&block)
    end

    # @public
    # Autoloads all files in the configured tasks_directory.
    #
    def register_tasks(&block)
      Bumbleworks::Task.autoload_all
    end

    # @public
    # Registers all process_definitions in the configured definitions_directory
    # with the Ruote engine.
    #
    def load_definitions!(options = {})
      Bumbleworks::ProcessDefinition.create_all_from_directory!(definitions_directory, options)
    end

    # @public
    # Resets Bumbleworks - clears configuration and setup variables, and
    # also resets the dashboard.
    #
    def reset!
      @configuration = nil
      Bumbleworks::Ruote.reset!
    end

    # @public
    # Launches the process definition with the given process name, as long as
    # that definition name is already registered with Bumbleworks.  If options
    # has an :entity key, attempts to extract the id and class name before
    # sending it, so it can be properly stored in workitem fields (and
    # re-instantiated later).
    #
    def launch!(process_definition_name, *args)
      extract_entity_from_fields!(args.first || {})
      pid = Bumbleworks::Ruote.launch(process_definition_name, *args)
      Bumbleworks::Process.new(pid)
    end

  private

    def extract_entity_from_fields!(fields)
      begin
        if entity = fields.delete(:entity)
          fields[:entity_id] = entity.respond_to?(:identifier) ? entity.identifier : entity.id
          fields[:entity_type] = entity.class.name
          raise InvalidEntity, "Entity#id must be non-null" unless fields[:entity_id]
        end
      rescue NoMethodError => e
        raise InvalidEntity, "Entity must respond to #identifier (or #id) and #class.name"
      end
    end
  end
end
