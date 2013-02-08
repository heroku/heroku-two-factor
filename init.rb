module Heroku::Command
  class TwoFactor < BaseWithApp
    def index
      status = heroku.two_factor_status
      if status["enabled"]
        display "Two-factor auth is enabled."
      else
        display "Two-factor is not enabled."
      end
    end

    def enable
      require "launchy"
      url = heroku.two_factor_status["url"]

      display "Opening OTP QRcode"
      base_path = File.dirname(__FILE__) + "/support"
      File.open("#{base_path}/code.js", "w") { |f| f.puts "var code = '#{url}';" }
      Launchy.open("#{base_path}/qrcode.html")

      display "Please add this OTP to your favorite application and enter it below."
      display "Keep in mind that two-factor will cause your API key to change, and expire every 30 days!"
      print "Security code: "
      code = ask

      heroku.two_factor_enable(code)
      display "Enabled two-factor authentication."
    end

    def disable
      heroku.two_factor_disable
      display "Disabled two-factor authentication."
    end
  end
end

class Heroku::Client
  def two_factor_status
    json_decode get("/account/two-factor").to_s
  end

  def two_factor_enable(code)
    json_decode put("/account/two-factor", :code => code).to_s
  end

  def two_factor_disable
    json_decode delete("/account/two-factor").to_s
  end

  # redefine process to add the two-factor auth header
  def process(method, uri, extra_headers={}, payload=nil)
    base_headers = (@auth_header || {}).merge(heroku_headers)
    headers      = base_headers.merge(extra_headers)
    args         = [method, payload, headers].compact

    resource_options = default_resource_options_for_uri(uri)

    begin
      response = resource(uri, resource_options).send(*args)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, SocketError
      host = URI.parse(realize_full_uri(uri)).host
      error "Unable to connect to #{host}"
    rescue RestClient::SSLCertificateNotVerified => ex
      host = URI.parse(realize_full_uri(uri)).host
      error "WARNING: Unable to verify SSL certificate for #{host}\nTo disable SSL verification, run with HEROKU_SSL_VERIFY=disable"
    end

    extract_warning(response)
    response
  end

  def two_factor_code=(code)
    @auth_header = { "Heroku-Two-Factor-Code" => code.to_s }
  end
end

module Heroku::Command
  # redefine run to rescue the two-factor auth error,
  # prompt for the security code and retry
  def self.run(cmd, arguments=[])
    begin
      object, method = prepare_run(cmd, arguments.dup)
      object.send(method)
    rescue Interrupt, StandardError, SystemExit => error
      # load likely error classes, as they may not be loaded yet due to defered loads
      require 'heroku-api'
      require 'rest_client'
      raise(error)
    end
  rescue Heroku::API::Errors::Unauthorized, RestClient::Unauthorized
    puts "Authentication failure"
    unless ENV['HEROKU_API_KEY']
      run "login"
      retry
    end
  rescue Heroku::API::Errors::VerificationRequired, RestClient::PaymentRequired => e
    retry if Heroku::Helpers.confirm_billing
  rescue Heroku::API::Errors::NotFound => e
    error extract_error(e.response.body) {
      e.response.body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
    }
  rescue RestClient::ResourceNotFound => e
    error extract_error(e.http_body) {
      e.http_body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
    }
  rescue Heroku::API::Errors::Locked => e
    app = e.response.headers[:x_confirmation_required]
    if confirm_command(app, extract_error(e.response.body))
      arguments << '--confirm' << app
      retry
    end
  rescue RestClient::Locked => e
    app = e.response.headers[:x_confirmation_required]
    if confirm_command(app, extract_error(e.http_body))
      arguments << '--confirm' << app
      retry
    end
  rescue Heroku::API::Errors::Timeout, RestClient::RequestTimeout
    error "API request timed out. Please try again, or contact support@heroku.com if this issue persists."
  rescue Heroku::API::Errors::ErrorWithResponse => e
    error extract_error(e.response.body)
  rescue RestClient::RequestFailed => e
    if e.response.headers.has_key?(:heroku_two_factor_required)
      display " !    Two-factor authentication required."
      print   " !    Please enter code: "
      code = ask
      display "Retrying..."
      Heroku::Auth.client.two_factor_code = code
      retry
    end
    error extract_error(e.http_body)
  rescue CommandFailed => e
    error e.message
  rescue OptionParser::ParseError
    commands[cmd] ? run("help", [cmd]) : run("help")
  rescue Excon::Errors::SocketError => e
    if e.message == 'getaddrinfo: nodename nor servname provided, or not known (SocketError)'
      error("Unable to connect to Heroku API, please check internet connectivity and try again.")
    else
      raise(e)
    end
  ensure
    display_warnings
  end
end