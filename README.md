# pass-gen-masked

A [pass / passwordstore](https://www.passwordstore.org/) extension to generate a Fastmail Masked email address.

## Requirements

- `curl`
- `jq`

## Fastmail API token

Create an API token under Settings → Privacy & Security → Integrations with the Masked Email scope. Then either:

- store it in pass: `pass insert fastmail/masked-email-token` (you can point it at a different entry with `PASS_FASTMAIL_TOKEN_PATH`), or
- export it as `PASS_FASTMAIL_TOKEN`.

## Usage

```shell
Usage:
    pass gen-masked [--force,-f] [--domain,-d domain] pass-name description
        Create a new Fastmail masked email with the given description and
        store it as an "email: <address>" line in pass-name. If pass-name
        already exists, the line is appended to it; if it already has an
        email line, --force is required to replace it.

        --domain,-d  Also set the masked email's "for domain" field
        --force,-f   Replace an existing email line without asking
```

## Examples

Create a masked email for a new entry:

```shell
pass gen-masked web/com/example "Test email for example.com"
```

Create a masked email for a domain:

```shell
pass gen-masked -d example.com web/com/example "Test email"
```
