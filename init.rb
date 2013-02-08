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

    def ask_for_credentials
      puts "Enter your Heroku credentials."

      print "Email: "
      user = ask

      print "Password (typing will be hidden): "
      password = running_on_windows? ? ask_for_password_on_windows : ask_for_password

      print "Two-factor code (leave blank if none): "
      @code = ask

      [user, api_key(user, password)]
    end
  end
end