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

      display "Please add this OTP to your favorite application and enter it below."
      display "Keep in mind that two-factor will cause your API key to change, and expire every 30 days!"
      print "Security code: "
      code = ask

      heroku.two_factor_enable(code)
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