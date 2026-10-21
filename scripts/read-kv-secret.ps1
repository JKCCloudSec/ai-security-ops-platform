# read-kv-secret.ps1
# Flagship v2 - Azure Automation runbook (PowerShell 7.2)
# Reads one Key Vault secret using the Automation account's system-assigned managed identity.
# There is no password, key or connection string anywhere in this script.
# Access: the identity has "Key Vault Secrets User" on this one secret only (least privilege).
# Lab data only - the secret value is fake.

$ErrorActionPreference = "Stop"

# Sign in to Azure as the managed identity
Connect-AzAccount -Identity | Out-Null

# Read the secret value
$value = Get-AzKeyVaultSecret -VaultName "kv-flagship-48213" -Name "contoso-crm-api-key" -AsPlainText

# Never print a full secret: job output is saved and other people can read it
Write-Output ("Secret read OK. Length: {0}. Starts with: {1}..." -f $value.Length, $value.Substring(0,4))
