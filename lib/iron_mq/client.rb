require 'json'
require 'logger'
require 'faraday'

module IronMQ

  class Client

    attr_accessor :token, :project_id, :queue_name, :logger,
        :scheme, :host, :port

    def initialize(options={})
      @logger = Logger.new(STDOUT)
      @logger.level=Logger::INFO

      @token = options[:token] || options['token']
      @project_id = options[:project_id] || options['project_id']
      @queue_name = options[:queue_name] || options['queue_name'] || "default"
      @scheme = options[:scheme] || options['scheme'] || "https"
      @host = options[:host] || options['host'] || "mq-aws-us-east-1.iron.io"
      @port = options[:port] || options['port'] || 443

      @base_url = "#{@scheme}://#{@host}:#{@port}/1"

      @rest = Faraday.new #Rest::Client.new

    end

    def messages
      return Messages.new(self)
    end

    def queues
      return Queues.new(self)
    end

    def base_url
      #"#{scheme}://#{host}:#{port}/1"
      @base_url
    end

    def full_url(path)
      url = "#{base_url}#{path}"
      url
    end

    def common_req_hash
      {
          :headers=>{"Content-Type" => 'application/json',
                     "Authorization"=>"OAuth #{@token}",
                     "User-Agent"=>"IronMQ Ruby Client"}
      }
    end


    def get(path, params={})
      url = full_url(path)
      @logger.debug 'url=' + url
      response = @rest.get do |req|
        req.url url
        req.headers = common_req_hash[:headers]
        req.params = params
      end
      
      @logger.debug 'GET response=' + response.inspect
      res = check_response(response)
      return res, response.status
    end

    def post(path, params={})
      url = full_url(path)
      @logger.debug 'url=' + url
      #response = @http_sess.post(path + "?oauth=#{@token}", {'oauth' => @token}.merge(params).to_json, {"Content-Type" => 'application/json'})

      response = @rest.post do |req|
        req.url url
        req.headers = common_req_hash[:headers]
        req.body = params.to_json
      end
      @logger.debug 'POST response=' + response.inspect
      res = check_response(response)
      #@logger.debug 'response: ' + res.inspect
      #body = response.body
      #res = JSON.parse(body)
      return res, response.status
    end


    def delete(path, params={})
      url = "#{base_url}#{path}"
      @logger.debug 'url=' + url
      req_hash = common_req_hash
      req_hash[:params] = params
      response = @rest.delete do |req|
        req.url url
        req.headers = common_req_hash[:headers]
        req.params = params
      end
      
      res = check_response(response)
      #body = response.body
      #res = JSON.parse(body)
      #@logger.debug 'response: ' + res.inspect
      return res, response.status
    end

    def check_response(response)
      # response.code    # http status code
      #response.time    # time in seconds the request took
      #response.headers # the http headers
      #response.headers_hash # http headers put into a hash
      #response.body    # the response body
      status = response.status
      body = response.body
      # todo: check content-type == application/json before parsing
      @logger.debug "response code=" + status.to_s
      @logger.debug "response body=" + body.inspect
      begin
        res = JSON.parse(body)
      rescue => ex
        # an unexpected error response
        raise IronMQ::Error.new("Status #{status}: #{ex.class.name}: #{ex.message}", :status=>status)
      end
      if status < 400

      else
        raise IronMQ::Error.new("Status #{status}: #{res["msg"]}", :status=>status)
      end
      res
    end

  end

  class Error < StandardError
    def initialize(msg, options={})
      super(msg)
      @options = options
    end

    def status
      @options[:status]
    end
  end


end

