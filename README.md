# pass-gen-masked

A [pass / passwordstore](https://www.passwordstore.org/) extension to generate a Fastmail Masked email address and store it directly in your password store.

*Because you should never give out your personal email to online websites.*

## Requirements

- `curl`
- `jq`

## Installation

From [`pass`](https://www.passwordstore.org/) documentation:

> In order to faciliate the large variety of uses users come up with, pass supports extensions. Extensions installed to `/usr/lib/password-store/extensions` (or some distro-specific variety of such) are always enabled. Extensions installed to `~/.password-store/.extensions/COMMAND.bash` are enabled if the `PASSWORD_STORE_ENABLE_EXTENSIONS` environment variable is `true` Read the man page for more details.

## Configuration

### Fastmail API token

Create an API token under Settings → Privacy & Security → Integrations with the Masked Email scope. Then either:

- store it in pass: `pass insert fastmail/masked-email-token` (you can point it at a different entry with `PASS_FASTMAIL_TOKEN_PATH`), or
- export it as `PASS_FASTMAIL_TOKEN`.

### Key used to store the masked email

`PASS_FASTMAIL_MASKED_KEY`: sets the stored key and default to `email`. In case you are using [passforios](https://github.com/mssun/passforios/wiki#use-the-pass-extension-to-fill-in-safari-and-apps), it's recommended to change it to `username` or `login`.

### Shell completion

For Bash:

```shell
cp pass-gen-masked.bash-completion ~/.bash_completion   # or append it if you already have one
```

For Fish:

```shell
cp pass-gen-masked.fish ~/.config/fish/conf.d/pass-gen-masked.fish
```

## Usage

```shell
Usage:
    pass gen-masked [--clip,-c] [--force,-f] [--domain,-d domain] pass-name description
        Create a new Fastmail masked email with the given description and
        store it as a "email: <address>" line in pass-name.

        A new (or empty) entry gets an empty first line and the address on
        the second line. If pass-name already has content, the line is
        appended to it; if it already has a "email:" line, --force is
        required to replace it.

        --clip,-c    Copy the address to the clipboard instead of printing it
        --domain,-d  Also set the masked email's "for domain" field
        --force,-f   Replace an existing "email:" line without asking
        --version,-v Show the version of this extension

Environment:
    PASS_FASTMAIL_MASKED_KEY   Key used in the entry (default: email)
```

## Examples

Create a masked email for a new entry:

```shell
pass gen-masked web/com/example "Test email for example.com"
```

Create a masked email with a domain entry on Fastmail:

```shell
pass gen-masked -d example.com web/com/example "Test email"
```
