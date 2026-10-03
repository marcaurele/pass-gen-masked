# fish completion for `pass gen-masked`
#
# Install as ~/.config/fish/conf.d/pass-gen-masked.fish. conf.d is used rather
# than completions/ because fish autoloads completions by command name, so a
# file named anything other than pass.fish would never be loaded for `pass`.

# Print the pass entries, relative to the store, without the .gpg suffix.
function __fish_pass_gen_masked_entries
    set -l prefix $HOME/.password-store
    set -q PASSWORD_STORE_DIR; and set prefix $PASSWORD_STORE_DIR
    set prefix (string trim -r -c / -- $prefix)
    find -L $prefix -name '*.gpg' -type f 2>/dev/null \
        | string replace -- "$prefix/" '' \
        | string replace -r '\.gpg$' '' \
        | sort
end

# Print how many positional arguments follow `gen-masked` on the command line
# (options and the value of -d/--domain are not counted). Fails if gen-masked
# has not been typed yet.
function __fish_pass_gen_masked_positionals
    set -l tokens (commandline -opc)
    set -l start (contains -i -- gen-masked $tokens); or return 1
    set -l n 0
    set -l skip 0
    if test $start -lt (count $tokens)
        for i in (seq (math $start + 1) (count $tokens))
            set -l t $tokens[$i]
            if test $skip -eq 1
                set skip 0
                continue
            end
            switch $t
                case -d --domain '-[!-]*d'
                    set skip 1
                case '-*'
                case '*'
                    set n (math $n + 1)
            end
        end
    end
    echo $n
end

# True when the next argument is the pass entry (first positional).
function __fish_pass_gen_masked_needs_entry
    set -l n (__fish_pass_gen_masked_positionals); or return 1
    set -l tokens (commandline -opc)
    # The argument of -d/--domain is free text.
    contains -- $tokens[-1] -d --domain; and return 1
    test $n -eq 0
end

# Subcommand, shown next to pass's built-in ones.
complete -c pass -n __fish_use_subcommand -a gen-masked \
    -d 'Create a Fastmail masked email and store it in an entry'

# Options.
complete -c pass -n '__fish_seen_subcommand_from gen-masked' -s c -l clip \
    -d 'Copy the address to the clipboard'
complete -c pass -n '__fish_seen_subcommand_from gen-masked' -s f -l force \
    -d 'Replace an existing key line without asking'
complete -c pass -n '__fish_seen_subcommand_from gen-masked' -s d -l domain -r \
    -d 'Set the masked email "for domain" field'
complete -c pass -n '__fish_seen_subcommand_from gen-masked' -s v -l version \
    -d 'Show the version'
complete -c pass -n '__fish_seen_subcommand_from gen-masked' -s h -l help \
    -d 'Show usage'

# Entry argument.
complete -c pass -n __fish_pass_gen_masked_needs_entry -f -a '(__fish_pass_gen_masked_entries)'
