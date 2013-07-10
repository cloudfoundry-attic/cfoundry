require "net/https"
require "multi_json"

module CFoundry
  module TraceHelpers
    PROTECTED_ATTRIBUTES = ['Authorization']

    def request_trace(request)
      return nil unless request
      info = ["REQUEST: #{request[:method]} #{request[:url]}"]
      info << "REQUEST_HEADERS:"
      info << header_trace(request[:headers])
      info << "REQUEST_BODY: #{request[:body]}" if request[:body]
      info.join("\n")
    end


    def response_trace(response)
      return nil unless response
      info = ["RESPONSE: [#{response[:status]}]"]
      info << "RESPONSE_HEADERS:"
      info << header_trace(response[:headers])
      info << "RESPONSE_BODY:"
      begin
        parsed_body = MultiJson.load(response[:body])
        info << MultiJson.dump(parsed_body, :pretty => true)
      rescue
        info << "#{response[:body]}"
      end
      info.join("\n")
    end

    private

    def header_trace(headers)
      headers.sort.map do |key, value|
        unless PROTECTED_ATTRIBUTES.include?(key)
          "  #{key} : #{value}"
        else
          "  #{key} : [PRIVATE DATA HIDDEN]"
        end
      end
    end
  end
end