#!/usr/bin/env bash
# pass gen-masked - Password Store Extension (https://www.passwordstore.org/)
#
# Generates a new Fastmail masked email address through the JMAP API and
# stores it in the password store.
#
# Requires: curl, jq
#
# Configuration (environment variables):
#   PASS_FASTMAIL_TOKEN        API token (overrides the pass entry below)
#   PASS_FASTMAIL_TOKEN_PATH   pass entry holding the token
#                              (default: fastmail/masked-email-token, first line)
#   PASS_FASTMAIL_SESSION_URL  JMAP session URL
#                              (default: https://api.fastmail.com/jmap/session)
#   PASS_FASTMAIL_MASKED_KEY   key under which the address is stored in the
#                              entry (default: email), e.g. "username"
#
# The token needs the "Masked Email" scope:
#   Fastmail > Settings > Privacy & Security > Integrations > API tokens

readonly GEN_MASKED_VERSION="1.0.0"
readonly FM_CAP_CORE="urn:ietf:params:jmap:core"
readonly FM_CAP_MASKED="https://www.fastmail.com/dev/maskedemail"

cmd_gen_masked_version() {
	echo "pass-gen-masked $GEN_MASKED_VERSION"
}

cmd_gen_masked_usage() {
	local key="${PASS_FASTMAIL_MASKED_KEY:-email}"
	cat <<-_EOF
	Usage:
	    $PROGRAM gen-masked [--clip,-c] [--force,-f] [--domain,-d domain] pass-name description
	        Create a new Fastmail masked email with the given description and
	        store it as a "$key: <address>" line in pass-name.

	        A new (or empty) entry gets an empty first line and the address on
	        the second line. If pass-name already has content, the line is
	        appended to it; if it already has a "$key:" line, --force is
	        required to replace it.

	        --clip,-c    Copy the address to the clipboard instead of printing it
	        --domain,-d  Also set the masked email's "for domain" field
	        --force,-f   Replace an existing "$key:" line without asking
	        --version,-v Show the version of this extension

	Environment:
	    PASS_FASTMAIL_MASKED_KEY   Key used in the entry (default: email)
	_EOF
}

cmd_gen_masked() {
	local opts force=0 clip_out=0 domain=""
	opts="$($GETOPT -o cfd:vh -l clip,force,domain:,version,help -n "$PROGRAM" -- "$@")"
	local err=$?
	eval set -- "$opts"
	while true; do
		case $1 in
			-c|--clip) clip_out=1; shift ;;
			-f|--force) force=1; shift ;;
			-d|--domain) domain="$2"; shift 2 ;;
			-v|--version) cmd_gen_masked_version; return 0 ;;
			-h|--help) cmd_gen_masked_usage; return 0 ;;
			--) shift; break ;;
		esac
	done

	if [[ $err -ne 0 || $# -ne 2 ]]; then
		cmd_gen_masked_usage >&2
		exit 1
	fi

	command -v curl >/dev/null || die "Error: curl is required."
	command -v jq >/dev/null || die "Error: jq is required."

	local key="${PASS_FASTMAIL_MASKED_KEY:-email}"
	[[ $key == *$'\n'* || $key == *:* ]] && die "Error: PASS_FASTMAIL_MASKED_KEY must not contain ':' or newlines."

	local path="${1%/}" description="$2"
	check_sneaky_paths "$path"
	local passfile="$PREFIX/$path.gpg"

	set_gpg_recipients "$(dirname -- "$path")"
	set_git "$passfile"

	# Fail early if we would have to overwrite something and weren't allowed to.
	local existing="" has_key=0
	if [[ -f $passfile ]]; then
		existing="$($GPG -d "${GPG_OPTS[@]}" "$passfile")" || exit $?
		if awk -v p="$key:" 'index($0, p) == 1 { f = 1 } END { exit !f }' <<<"$existing"; then
			has_key=1
			if [[ $force -eq 0 ]]; then
				[[ -t 0 ]] || die "Error: $path already has a '$key:' line. Use --force to replace it."
				yesno "A '$key:' line already exists in $path. Replace it?"
			fi
		fi
	fi

	# --- API token ---------------------------------------------------------
	local token="${PASS_FASTMAIL_TOKEN:-}"
	if [[ -z $token ]]; then
		local token_path="${PASS_FASTMAIL_TOKEN_PATH:-fastmail/masked-email-token}"
		token="$("$PROGRAM" show "$token_path" 2>/dev/null | head -n1)"
		[[ -n $token ]] || die "Error: no Fastmail API token. Set PASS_FASTMAIL_TOKEN or store it in pass at '$token_path'."
	fi

	# Pass the token to curl through a config on a pipe so it never shows up in `ps`.
	_fm_curl() {
		curl -fsS --config <(printf 'header = "Authorization: Bearer %s"\n' "$token") "$@"
	}

	# --- JMAP session ------------------------------------------------------
	local session_url="${PASS_FASTMAIL_SESSION_URL:-https://api.fastmail.com/jmap/session}"
	local session api_url account_id
	session="$(_fm_curl "$session_url")" || die "Error: could not fetch the Fastmail JMAP session (bad token?)."
	api_url="$(jq -r '.apiUrl // empty' <<<"$session")"
	account_id="$(jq -r --arg cap "$FM_CAP_MASKED" '.primaryAccounts[$cap] // empty' <<<"$session")"
	[[ -n $api_url && -n $account_id ]] || die "Error: token lacks the Masked Email scope (no masked email account in the session)."

	# --- Create the masked email ------------------------------------------
	local request response email
	request="$(jq -n \
		--arg core "$FM_CAP_CORE" \
		--arg cap "$FM_CAP_MASKED" \
		--arg acc "$account_id" \
		--arg desc "$description" \
		--arg domain "$domain" '
		{
			using: [$core, $cap],
			methodCalls: [[
				"MaskedEmail/set",
				{
					accountId: $acc,
					create: { new: (
						{ state: "enabled", description: $desc }
						+ (if $domain != "" then { forDomain: $domain } else {} end)
					) }
				},
				"0"
			]]
		}')"

	response="$(_fm_curl -H 'Content-Type: application/json' --data "$request" "$api_url")" \
		|| die "Error: the masked email request failed."

	email="$(jq -r '
		.methodResponses[0] as $r
		| if $r[0] == "error" then "ERR:" + ($r[1].description // $r[1].type // "unknown error")
		  elif $r[1].notCreated.new then "ERR:" + ($r[1].notCreated.new.description // $r[1].notCreated.new.type // "unknown error")
		  else ($r[1].created.new.email // "ERR:no email in response") end' <<<"$response")"
	[[ $email == ERR:* ]] && die "Error: Fastmail refused to create the masked email: ${email#ERR:}"

	# --- Store it ----------------------------------------------------------
	local line="$key: $email" content
	if [[ -z ${existing//[[:space:]]/} ]]; then
		# New or empty entry: empty first line, address on the second.
		content=$'\n'"$line"
	elif [[ $has_key -eq 1 ]]; then
		# Replace the existing line in place.
		content="$(awk -v p="$key:" -v l="$line" 'index($0, p) == 1 { print l; next } { print }' <<<"$existing")"
	else
		content="$existing"$'\n'"$line"
	fi

	mkdir -p -- "$PREFIX/$(dirname -- "$path")"
	set_gpg_recipients "$(dirname -- "$path")"
	$GPG -e "${GPG_RECIPIENT_ARGS[@]}" -o "$passfile" "${GPG_OPTS[@]}" <<<"$content" \
		|| die "Error: could not encrypt $path."
	git_add_file "$passfile" "Add masked email for $path (${description})."

	if [[ $clip_out -eq 1 ]]; then
		clip "$email" "masked email for $path"
	else
		echo "$email"
	fi
}

case "$1" in
	version|--version|-v) cmd_gen_masked_version ;;
	help|--help|-h)       shift; cmd_gen_masked_usage "$@" ;;
	*)                    cmd_gen_masked "$@" ;;
esac
exit 0
