module Heroku::Command
  class Otp < BaseWithApp
    def enable
      require "launchy"
      url = heroku.otp_status["url"]

      display "Opening OTP QRcode"
      base_path = File.dirname(__FILE__) + "/support"
      File.open("#{base_path}/code.js", "w") { |f| f.puts "var code = '#{url}';" }
      Launchy.open("#{base_path}/qrcode.html")

      display "Please add this OTP to your favorite application and enter it below"
      print "Security code: "
      code = ask

      heroku.otp_enable(code)
      display "OTP enabled"
    end

    def disable
      heroku.otp_disable
      display "Disabled OTP on account"
    end

    def status
      status = heroku.otp_status
      if status["enabled"]
        display "OTP is enabled."
      else
        display "OTP is not enabled."
      end
    end
  end
end


module Heroku::Otp
  def otp_status
    json_decode get("/account/two-factor").to_s
  end

  def otp_enable(code)
    json_decode put("/account/two-factor", :code => code).to_s
  end

  def otp_disable
    json_decode delete("/account/two-factor").to_s
  end
end

Heroku::Client.send(:include, Heroku::Otp)
