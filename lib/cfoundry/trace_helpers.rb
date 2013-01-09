require "net/https"
require "multi_json"

module CFoundry
  module TraceHelpers

    def request_trace(request)
      return nil unless request
      info = ["REQUEST: #{request.method} #{request.path}"]
      info << "REQUEST_HEADERS:"
      request.to_hash.sort.each do |key, value|
        info << "  #{key} : #{value}"
      end
      info << "REQUEST_BODY: #{request.body}" if request.body
      info.join("\n")
    end


    def response_trace(response)
      return nil unless response
      info = ["RESPONSE: [#{response.code}]"]
      info << "RESPONSE_HEADERS:"
      response.to_hash.sort.each do |key, value|
        info << "  #{key} : #{value}"
      end
      begin
        parsed_body = MultiJson.load(response.body)
        info << MultiJson.dump(parsed_body, :pretty => true)
      rescue
        info << "#{response.body}"
      end
      info.join("\n")
    end

  end
end