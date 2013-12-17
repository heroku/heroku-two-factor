# Two-factor auth plugin to the Heroku CLI

This gives you commands to toggle 2FA on your account, and generate recovery tokens.

## Usage

Install normally:

```
$ heroku plugins:install git@github.com:heroku/heroku-two-factor.git
```

Then to enable 2FA:

```
$ heroku 2fa:enable
```

The commands available are:

```
2fa:enable                   #  Enable 2fa on your account
2fa:enable                   #  Disable 2fa on your account
2fa:generate-recovery-codes  #  Generates (and replaces) recovery codes
```
