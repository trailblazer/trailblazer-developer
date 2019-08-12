require "faraday"
require "base64"
require "json"
require "representable/json"

module Trailblazer::Developer
  module Client
    Diagram = Struct.new(:id, :body)

    class Diagram::Representer < Representable::Decorator
      include Representable::JSON
      property :id
      property :body, as: :diagram
    end

    module_function

    def Diagram(id, body)
      Diagram.new(id, body).freeze
    end

    def import(id:, query:"", **options)
      token = retrieve_token(**options)
      export_diagram(id: id, token: token, query: query, **options)
    end

    def retrieve_token(email:, password:, url: "/login", **options)
      body = JSON.generate({login: {email: email, password: password}})

      response = request(token: nil, method: :post, url: url, body: body, **options)

      return false unless response.status == 302

      token = CGI::Cookie.parse(response.headers["set-cookie"])["token"][0]
    end

    def export_diagram(id:, query:, **options)
      response = request(body: nil, url: "/api/v1/diagrams/#{id}/export#{query}", method: :get, **options)

#      parse_response(response)
      response.body
    end

    # DISCUSS: do we need that?
    def new_diagram(token:, **options)
      response = request(body: nil, url: "/api/v1/diagrams/new", method: :get, token: token, **options)

      # TODO: use Dry::Struct
      # TODO: handle unauthorized/errors
      parse_response(response)
    end

    def request(host:, url:, method:, token:, body:, **)
      conn = Faraday.new(url: host)

      response = conn.send(method) do |req|
        req.url url
        req.headers["Content-Type"] = "application/json"
        req.body = body
        req.headers["Authorization"] = token
      end
    end

    def parse_response(response)
      diagram = Diagram.new
      Diagram::Representer.new(diagram).from_json(response.body) # a parsed hash would be cooler?

      diagram
    end

    # TODO: remove me!
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
