module Bumbleworks
  class Task
    class Finder
      include Enumerable

      def initialize(queries = [])
        @queries = queries
      end

      def by_nickname(nickname)
        @queries << proc { |wi| wi['fields']['params']['task'] == nickname }
        self
      end

      def for_roles(identifiers)
        identifiers ||= []
        @queries << proc { |wi| identifiers.include?(wi['participant_name']) }
        self
      end

      def for_role(identifier)
        for_roles([identifier])
      end

      def for_claimant(token)
        @queries << proc { |wi| wi['fields']['params']['claimant'] == token }
        self
      end

      def for_entity(entity)
        @queries << proc { |wi|
          (wi['fields'][:entity_type] || wi['fields']['entity_type']) == entity.class.name &&
            (wi['fields'][:entity_id] || wi['fields']['entity_id']) == entity.identifier
        }
        self
      end

      def all
        workitems = Bumbleworks.dashboard.storage_participant.send(:do_select, {}) { |wi|
          @queries.all? { |q| q.call(wi) }
        }
        from_workitems(workitems)
      end

      def each(&block)
        all.each(&block)
      end

      def empty?
        all.empty?
      end

      def next_available(options = {})
        options[:timeout] ||= 5

        start_time = Time.now
        while first.nil?
          if (Time.now - start_time) > options[:timeout]
            raise Bumbleworks::Task::AvailabilityTimeout, "No tasks found matching criteria in time"
          end
          sleep 0.1
        end
        first
      end

    private

      def from_workitems(workitems)
        workitems.map { |wi|
          Task.new(wi) if wi.params['task']
        }.compact
      end
    end
  end
end