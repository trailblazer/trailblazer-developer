require "faraday"

module Trailblazer::Developer
  module Client
    def self.push(operation:, name:)
      xml = Trailblazer::Diagram::BPMN.to_xml(operation["__activity__"], operation["__sequence__"].map(&:id))
      token = "Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJub25lIn0.eyJpZCI6MywidXNlcm5hbWUiOiJhcG90b25pY2siLCJlbWFpbCI6Im5pY2tAdHJhaWxibGF6ZXIudG8ifQ." # rubocop:disable Metrics/LineLength
      conn = Faraday.new(url: "https://api.trb.to")
      response = conn.post do |req|
        req.url "/dev/v1/import"
        req.headers["Content-Type"] = "application/json"
        req.headers["Authorization"] = token
        require "base64"

        req.body = %({ "name": "#{name}", "xml":"#{Base64.strict_encode64(xml)}" })
      end

      puts response.status.inspect
    end
  end
end
