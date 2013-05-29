module CFoundry::V2::ModelMagic
  module HasSummary
    def has_summary(actions = {})
      #
      # def summary
      #
      define_method(:summary) do
        @client.base.get("v2", plural_object_name, @guid, "summary", :accept => :json)
      end

      #
      # def summarize!
      #
      define_method(:summarize!) do |*args|
        body, _ = args

        body ||= summary

        body.each do |key, val|
          if act = actions[key]
            instance_exec(val, &act)

          elsif self.class.attributes[key]
            self.send(:"#{key}=", val)

          elsif self.class.to_many_relations[key]
            singular = key.to_s.sub(/s$/, "").to_sym

            vals = val.collect do |sub|
              obj = @client.send(singular, sub[:guid], true)
              obj.summarize! sub
              obj
            end

            self.send(:"#{key}=", vals)

          elsif self.class.to_one_relations[key]
            obj = @client.send(key, val[:guid], true)
            obj.summarize! val

            self.send(:"#{key}=", obj)
          end
        end

        nil
      end
    end
  end
end
