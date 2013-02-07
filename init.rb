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

      display "Please add this OTP to your favorite application and enter it below"
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


module Heroku::Otp
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

Heroku::Client.send(:include, Heroku::Otp)
