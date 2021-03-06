require 'kashmir/plugins/memory_caching'
require 'kashmir/plugins/null_caching'

module Kashmir
  module Caching

    def from_cache(representation_definition, object)
      log("read: #{log_key(object, representation_definition)}", :debug)

      cached_representation = Kashmir.caching.from_cache(representation_definition, object)

      if cached_representation
        log("hit: #{log_key(object, representation_definition)}")
      else
        log("miss: #{log_key(object, representation_definition)}")
      end

      cached_representation
    end

    def bulk_from_cache(representation_definition, objects)
      class_name = objects.length > 0 ? objects.first.class.to_s : ''
      log("read_multi: [#{objects.length}]#{class_name} : #{representation_definition}", :debug)
      Kashmir.caching.bulk_from_cache(representation_definition, objects)
    end

    def store_presenter(representation_definition, representation, object, ttl)
      log("write TTL: #{ttl}: #{log_key(object, representation_definition)}", :debug)
      Kashmir.caching.store_presenter(representation_definition, representation, object, ttl)
    end

    def bulk_write(representation_definition, representations, objects, ttl)
      class_name = objects.length > 0 ? objects.first.class.to_s : ''
      log("write_multi: TTL: #{ttl}: [#{objects.length}]#{class_name} : #{representation_definition}", :debug)
      Kashmir.caching.bulk_write(representation_definition, representations, objects, ttl)
    end

    def log_key(object, representation_definition)
      "#{object.class.name}-#{object.id}-#{representation_definition}"
    end

    def log(message, level=:info)
      Kashmir.logger.send(level, ("\nKashmir::Caching #{message}\n"))
    end

    module_function :from_cache, :bulk_from_cache, :bulk_write, :store_presenter, :log_key, :log
  end
end
