# frozen_string_literal: true

module GitHubClassroom
  module LTI
    module Mixins
      module RequestSigning
        # given an endpoint, build a Faraday connection which satisfies the LTI standard
        def signed_request(endpoint, method: :post, headers: {}, query: {}, body: nil)
          req = build_net_req(endpoint, method, headers, query, body)

          sign_request!(req, @consumer_key, @secret)

          signed_headers = {}
          req.each_header { |header, value| signed_headers[header] = value }

          Faraday.new(url: req.uri, headers: signed_headers) do |conn|
            conn.response :raise_error
            conn.adapter Faraday.default_adapter
          end
        end

        private

        # builds a Net::HTTP request from endpoint and options
        def build_net_req(endpoint, method = :post, headers = {}, query = {}, body = nil)
          uri = URI.parse(endpoint)
          uri.query = URI.encode_www_form(query)

          klass = "Net::HTTP::#{method.to_s.capitalize}".constantize
          req = klass.new(uri)

          headers.each_pair { |header, value| req[header] = value }
          req.body = body

          req
        end

        def sign_request!(req, consumer_key, secret, lti_version: 1.1)
          consumer = OAuth::Consumer.new(consumer_key, secret)

          http = Net::HTTP.new(req.uri.host, req.uri.port)
          if lti_version == 1.1
            # necessary to override because LTI 1.1 expects a body hash
            # even when the body is empty, as it is in GET requests
            req.instance_variable_set(:@request_has_body, true)
            req.oauth!(http, consumer, nil, scheme: "header")
          elsif lti_version == 1.0
            req.oauth!(http, consumer, nil, scheme: "body")
          end

          req
        end
      end
    end
  end
end
