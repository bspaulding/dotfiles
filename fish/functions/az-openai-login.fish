function az-openai-login --description 'Set AZURE_OPENAI_API_KEY from a fresh Azure access token for cognitive services'
  if not command -sq az
    echo "az (Azure CLI) not found. Install with one of:" >&2
    echo "  nix profile add nixpkgs#azure-cli" >&2
    echo "  brew install azure-cli" >&2
    return 1
  end

  set -gx AZURE_OPENAI_API_KEY (az account get-access-token --resource https://cognitiveservices.azure.com --query accessToken -o tsv)

  if test $status -ne 0
    echo "az-openai-login: failed to get access token. Are you logged in (az login)?" >&2
    return 1
  end

  echo "AZURE_OPENAI_API_KEY set (token expires per Azure AD policy)"
end