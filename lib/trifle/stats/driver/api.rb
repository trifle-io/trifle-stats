# frozen_string_literal: true

require 'json'
require 'net/http'
require 'stringio'
require 'time'
require 'uri'
require 'zlib'
require_relative '../version'

module Trifle
  module Stats
    module Driver
      class Api
        ENDPOINT = URI('https://app.trifle.io/api/v1/metrics')
        TIMEOUT = 10
        ERROR_BODY_LIMIT = 1024

        class Error < Trifle::Stats::Error
          attr_reader :status, :response_body, :retry_after, :delivery_unknown

          def initialize(message, status: nil, response_body: nil, retry_after: nil, delivery_unknown: false)
            super(message)
            @status = status
            @response_body = response_body
            @retry_after = retry_after
            @delivery_unknown = delivery_unknown
          end
        end

        class NetHttpTransport
          def call(uri:, request:, timeout:)
            Net::HTTP.start(
              uri.hostname,
              uri.port,
              use_ssl: uri.scheme == 'https',
              open_timeout: timeout,
              read_timeout: timeout
            ) { |http| http.request(request) }
          end
        end

        attr_reader :token, :project_id

        def initialize(token:, project_id:, transport: NetHttpTransport.new)
          raise ArgumentError, 'token must not be empty' if token.to_s.strip.empty?
          raise ArgumentError, 'project_id must not be empty' if project_id.to_s.strip.empty?

          @token = token.to_s
          @project_id = project_id.to_s
          @transport = transport
        end

        def description
          self.class.name
        end

        def bypass_buffer?
          true
        end

        def direct_write(operation:, key:, at:, values:, untracked: false)
          body = gzip(JSON.generate(
                        operation: operation.to_s,
                        key: key,
                        at: at.to_time.iso8601(6),
                        values: values,
                        untracked: untracked
                      ))
          request = Net::HTTP::Post.new(ENDPOINT)
          request['Authorization'] = "Bearer #{token}"
          request['X-Trifle-Source-Id'] = project_id
          request['Content-Type'] = 'application/json'
          request['Accept'] = 'application/json'
          request['Content-Encoding'] = 'gzip'
          request['User-Agent'] = "trifle-stats-ruby/#{Trifle::Stats::VERSION}"
          request.body = body

          response = @transport.call(uri: ENDPOINT, request: request, timeout: TIMEOUT)
          return true if response.code.to_i.between?(200, 299)

          response_body = response.body.to_s.byteslice(0, ERROR_BODY_LIMIT)
          raise Error.new(
            "Trifle API returned HTTP #{response.code}",
            status: response.code.to_i,
            response_body: response_body,
            retry_after: response['Retry-After']
          )
        rescue Error
          raise
        rescue StandardError => e
          raise Error.new("Trifle API request failed: #{e.message}", delivery_unknown: true), cause: e
        end

        def inc(*)
          unsupported!(:track)
        end

        def set(*)
          unsupported!(:assert)
        end

        def get(*)
          unsupported!(:values)
        end

        def ping(*)
          unsupported!(:beam)
        end

        def scan(*)
          unsupported!(:scan)
        end

        private

        def gzip(value)
          output = StringIO.new
          Zlib::GzipWriter.wrap(output) { |writer| writer.write(value) }
          output.string
        end

        def unsupported!(operation)
          message = "#{operation} must be called through Trifle::Stats; " \
                    'API driver does not support direct storage operations'
          raise Error, message
        end
      end
    end
  end
end
