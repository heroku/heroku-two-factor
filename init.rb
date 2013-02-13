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

      display "Opening OTP QRcode..."
      url = heroku.two_factor_status["url"]
      File.open(js_code_file, "w") { |f| f.puts "var code = '#{url}';" }
      Launchy.open("#{support_path}/qrcode.html")

      display "WARN: this will your API key to change, and expire every 30 days!"
      display "Please add this OTP to your favorite application and login below."

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
    ensure
      File.delete(js_code_file) rescue Errno::ENOENT
    end

    def disable
      heroku.two_factor_disable
      display "Disabled two-factor authentication."
    end

    protected

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
    json_decode put("/account/two-factor", {}, {"Heroku-Two-Factor-Code" => code.to_s}).to_s
  end

  def two_factor_disable
    json_decode delete("/account/two-factor").to_s
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