function source-env --description 'Source a bash-style .env file into the current fish session'
  set -l env_file $argv[1]

  if test -z "$env_file"
    set env_file .env
  end

  if not test -f "$env_file"
    echo "source-env: file not found: $env_file" >&2
    return 1
  end

  while read -l line
    # skip blank lines and comments
    if string match -qr '^\s*(#|$)' -- $line
      continue
    end

    # strip optional leading 'export '
    set -l line (string replace -r '^export\s+' '' -- $line)

    # split on first '=' only
    set -l key (string split -m 1 '=' -- $line)[1]
    set -l val (string split -m 1 '=' -- $line)[2]

    # strip surrounding quotes
    set -l val (string replace -r "^(['\"])(.*)\1\$" '$2' -- $val)

    set -gx $key $val
  end < $env_file
end
