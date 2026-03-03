function aws-export-credentials --description 'Export AWS credentials for a given profile'
  if test (count $argv) -eq 0
    echo "Usage: aws-export-credentials <profile-name>" >&2
    return 1
  end

  set -l profile $argv[1]

  # Get credentials in process format (JSON) which includes session token
  set -l creds_json (aws configure export-credentials --profile $profile --format process 2>&1)

  if test $status -ne 0
    echo "Error: Failed to get credentials for profile '$profile'" >&2
    echo "Make sure you've run: aws sso login --profile $profile" >&2
    return 1
  end

  # Parse JSON and export credentials (use --groups-only to extract just the capture group)
  set -gx AWS_ACCESS_KEY_ID (echo $creds_json | string match -rg '"AccessKeyId"\s*:\s*"([^"]+)"')
  set -gx AWS_SECRET_ACCESS_KEY (echo $creds_json | string match -rg '"SecretAccessKey"\s*:\s*"([^"]+)"')
  set -gx AWS_SESSION_TOKEN (echo $creds_json | string match -rg '"SessionToken"\s*:\s*"([^"]+)"')

  # Also set AWS_PROFILE for compatibility
  set -gx AWS_PROFILE $profile

  # Get and set region
  set -l region (aws configure get region --profile $profile 2>/dev/null)
  if test -n "$region"
    set -gx AWS_DEFAULT_REGION $region
    set -gx AWS_REGION $region
  end

  echo "✓ Exported credentials for profile '$profile'"
end
