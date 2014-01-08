# Two-factor authentication on Heroku

Heroku accounts can now rely on another layer of protection: once turned on, any access to the account will need to be confirmed with a secondary code, usually issued by an iPhone/Android app installed on the account owner's phone.

This plugins gives you commands to toggle two-factor on your account, and generate recovery tokens.

**Please note**: enabling two-factor auth on your account will cause your Heroku API key to change, and expire every 30 days. This means you'll need to re-authorize (i.e. re-enter your password and auth code) every 30 days.

## Getting started

First, you'll need an authenticator app. A couple of recommendations:

* Authy ([iOS](https://itunes.apple.com/us/app/authy/id494168017?mt=8), [Android](https://play.google.com/store/apps/details?id=com.authy.authy))
* Google Authenticator ([iOS](https://itunes.apple.com/us/app/google-authenticator/id388497605?mt=8), [Android](https://play.google.com/store/apps/details?id=com.google.android.apps.authenticator2&hl=en))

(Technical note: Heroku uses the standard [TOTP](http://en.wikipedia.org/wiki/Time-based_One-time_Password_Algorithm) algorithm, so Heroku's two-factor auth should work with any app supporting that protocol. Authy and Google Authenticator have been verified as working, but there are likely any number of other options that will work, as well as several [open source](http://rubydoc.info/gems/rotp/1.4.1/frames) [implementations](https://github.com/bdauvergne/python-oath))

Next, install the two-factor auth plugin:

```bash
$ heroku plugins:install git@github.com:heroku/heroku-two-factor.git
```

And enable it:

```bash
$ heroku 2fa:enable
WARN: this will change your API key, and expire it every 30 days!
To enable, add the following OTP to your favorite application, and login below:

    (QR code here)

Enter your Heroku credentials.
Email: jacob@heroku.com
Password (typing will be hidden):
Two-factor code (leave blank if none): ######
Enabled two-factor authentication.
```

You'll scan the QR code displayed above into the authenticator app, and then use the code it generates to verify that you've got things set up correctly.

## Recovery codes

If you lose your device, you'll be locked out of your account (yikes!). So, as a backup, you should generate a set of recovery codes:

```bash
$ heroku 2fa:generate-recovery-codes
Two-factor code: 066055
Recovery codes:
...
```

These are one-time-use codes that will get you into your account if you don't have your device. Keep them somewhere secure -- a secure note in something like LastPass or 1Password is probably a good place for them.

## Oauth clients

Two-factor should work transparently for OAuth clients. The regular OAuth flow will make sure the user has a valid two-factor session, or will request the code to initiate one.

API requests authorized with OAuth access tokens for accounts with two-factor enabled work the same.
