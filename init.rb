# encoding: utf-8
base = File.dirname(__FILE__)
$: << "#{base}/vendor/rqrcode-0.4.2/lib/"
$: << "#{base}/vendor/term-ansicolor-1.0.7/lib/"
require "rqrcode"
require "term/ansicolor"

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

      display "WARN: this will change your API key, and expire it every 30 days!"
      display "To enable, add the following OTP to your favorite application, and login below:"

      url = heroku.two_factor_status["url"]
      display_qrcode(url)

      # ask for credentials again, this time storing the password in memory
      Heroku::Auth.credentials = Heroku::Auth.ask_for_credentials

      # make the actual API call to enable two factor
      heroku.two_factor_enable(Heroku::Auth.two_factor_code)

      # get a new api key using the password and two factor
      new_api_key = Heroku::Auth.api_key(
        Heroku::Auth.user, Heroku::Auth.current_session_password)

      # store new api key to disk
      Heroku::Auth.credentials = [Heroku::Auth.user, new_api_key]
      Heroku::Auth.write_credentials

      display "Enabled two-factor authentication."
    end

    def disable
      heroku.two_factor_disable
      display "Disabled two-factor authentication."
    end

    def generate_recovery_codes
      print "Two-factor code: "
      code = ask

      recovery_codes = heroku.two_factor_recovery_codes(code)
      display "Recovery codes:"
      recovery_codes.each { |c| display c }
    rescue RestClient::Unauthorized => e
      error Heroku::Command.extract_error(e.http_body)
    end

    protected

    def display_qrcode(url)
      qr = RQRCode::QRCode.new(url, :size => 4, :level => :l)

      # qr.to_s doesn't work unfortunately. bringing that
      # over, and using two characters per position instead
      color = Term::ANSIColor
      white = color.white { "██" }
      black = color.black { "██" }
      line  = white * (qr.module_count + 2)

      code = qr.modules.map do |row|
        contents = row.map do |col|
          col ? black : white
        end.join
        white + contents + white
      end.join("\n")

      puts line
      puts code
      puts line
    end
  end
end

class Heroku::Client
  def two_factor_status
    json_decode get("/account/two-factor").to_s
  end

  def two_factor_enable(code)
    json_decode put("/account/two-factor", {},
      {"Heroku-Two-Factor-Code" => code.to_s}).to_s
  end

  def two_factor_disable
    json_decode delete("/account/two-factor").to_s
  end

  def two_factor_recovery_codes(code)
    json_decode post("/account/two-factor/recovery-codes", {},
      {"Heroku-Two-Factor-Code" => code.to_s}).to_s
  end
end

class Heroku::Auth
  class << self
    alias :default_params_without_two_factor :default_params

    def default_params
      params = default_params_without_two_factor
      return params unless @code
      params[:headers].merge!("Heroku-Two-Factor-Code" => @code)
      params
    end

    # redefine ask_for_credentials to also ask for the 2fa code,
    # AND to store the password so we can reuse it later
    def ask_for_credentials
      puts "Enter your Heroku credentials."

      print "Email: "
      user = ask

      print "Password (typing will be hidden): "
      @current_session_password = running_on_windows? ? ask_for_password_on_windows : ask_for_password

      print "Two-factor code (leave blank if none): "
      @code = ask
      @code = nil if @code == ""

      [user, api_key(user, @current_session_password)]
    end

    def current_session_password
      @current_session_password
    end

    def two_factor_code
      @code
    end

    # do not touch ssh keys!
    def associate_or_generate_ssh_key
    end
  end
end