# encoding: utf-8
base = File.dirname(__FILE__)
$: << "#{base}/vendor/rqrcode-0.4.2/lib/"
$: << "#{base}/vendor/term-ansicolor-1.0.7/lib/"
require "rqrcode"
require "term/ansicolor"

module Heroku::Command
  class TwoFactor < BaseWithApp
    # 2fa
    #
    # Display whether two-factor is enabled or not
    #
    def index
      status = heroku.two_factor_status
      if status["enabled"]
        display "Two-factor auth is enabled."
      else
        display "Two-factor is not enabled."
      end
    end

    alias_command "2fa", "twofactor"

    # 2fa:enable
    #
    # Enable 2fa on your account
    #
    # --browser # display QR code in a browser for better compatiblity
    #
    def enable
      display "WARN: this will change your API key, and expire it every 30 days!"

      url = heroku.two_factor_status["url"]

      if options[:browser]
        open_qrcode_in_browser(url)
      else
        render_qrcode(url)
      end

      # ask for credentials again, this time storing the password in memory
      Heroku::Auth.credentials = Heroku::Auth.ask_for_credentials(true)

      # make the actual API call to enable two factor
      heroku.two_factor_enable(Heroku::Auth.two_factor_code)

      # get a new api key using the password and two factor
      new_api_key = Heroku::Auth.api_key(
        Heroku::Auth.user, Heroku::Auth.current_session_password)

      # store new api key to disk
      Heroku::Auth.credentials = [Heroku::Auth.user, new_api_key]
      Heroku::Auth.write_credentials

      # store a hint so toolbelt will keep asking for second factor on login
      Heroku::Auth.enable_two_factor

      display "Enabled two-factor authentication."
    ensure
      # make sure to clean file containing js file (for browser)
      if options[:browser]
        File.delete(js_code_file) rescue Errno::ENOENT
      end
    end

    alias_command "2fa:enable", "twofactor:enable"

    # 2fa:disable
    #
    # Disable 2fa on your account
    #
    def disable
      heroku.two_factor_disable
      Heroku::Auth.disable_two_factor
      display "Disabled two-factor authentication."
    end

    alias_command "2fa:disable", "twofactor:disable"

    # 2fa:generate-recovery-codes
    #
    # Generates (and replaces) recovery codes
    #
    def generate_recovery_codes
      code = Heroku::Auth.ask_for_second_factor

      recovery_codes = heroku.two_factor_recovery_codes(code)
      display "Recovery codes:"
      recovery_codes.each { |c| display c }
    rescue RestClient::Unauthorized => e
      error Heroku::Command.extract_error(e.http_body)
    end

    alias_command "2fa:generate-recovery-codes", "twofactor:generate_recovery_codes"

    protected

    def open_qrcode_in_browser(url)
      require "launchy"
      display "To enable scan the QR code opened in your browser and login below."
      File.open(js_code_file, "w") { |f| f.puts "var code = '#{url}';" }
      Launchy.open("#{support_path}/qrcode.html")
    end

    def render_qrcode(url)
      display "To enable scan the QR rendered below then login again."
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
      puts "If you can't scan this qrcode please use 2fa:enable --browser"
      puts
    end

    def support_path
      File.dirname(__FILE__) + "/support"
    end

    def js_code_file
      "#{support_path}/code.js"
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
    def ask_for_credentials(force_2fa=false)
      puts "Enter your Heroku credentials."

      print "Email: "
      user = ask

      print "Password (typing will be hidden): "
      @current_session_password = running_on_windows? ? ask_for_password_on_windows : ask_for_password

      if force_2fa || two_factor_enabled?
        ask_for_second_factor
      end

      [user, api_key(user, @current_session_password)]
    end

    def ask_for_second_factor
      print "Two-factor code: "
      @code = ask
      @code = nil if @code == ""
      @code
    end

    def api_key(user = get_credentials[0], password = get_credentials[1])
      require("heroku-api")
      api = Heroku::API.new(default_params)
      api.post_login(user, password).body["api_key"]
    rescue Heroku::API::Errors::Forbidden => e
      two_factor_error = e.response.headers.has_key?("Heroku-Two-Factor-Required")
      if two_factor_error && !two_factor_enabled?
        enable_two_factor
        ask_for_second_factor
        retry
      end
    end

    def current_session_password
      @current_session_password
    end

    def two_factor_code
      @code
    end

    def two_factor_enabled?
      File.exists?(two_factor_file)
    end

    def enable_two_factor
      File.write(two_factor_file, "")
    end

    def disable_two_factor
      File.delete(two_factor_file)
    rescue Errno::ENOENT
    end

    # simple file indicating 2fa is enabled
    def two_factor_file
      File.expand_path("#{Heroku::Helpers.home_directory}/.heroku/two_factor")
    end

    # do not touch ssh keys!
    def associate_or_generate_ssh_key
    end
  end
end
