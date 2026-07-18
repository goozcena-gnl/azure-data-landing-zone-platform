#!/usr/bin/env bash
# Prepare a secure, idempotent Azure Storage backend for Terraform.
# Bash >= 4.4 is required.

set -Eeuo pipefail
IFS=$'\n\t'

readonly SCRIPT_NAME="${0##*/}"
readonly MIN_BASH_MAJOR=4
readonly MIN_BASH_MINOR=4
readonly MIN_AZ_CLI_VERSION="2.26.0"
readonly STORAGE_BLOB_DATA_CONTRIBUTOR="Storage Blob Data Contributor"
readonly STORAGE_BLOB_DATA_OWNER="Storage Blob Data Owner"
readonly DATA_PLANE_RETRY_ATTEMPTS=12
readonly DATA_PLANE_RETRY_INITIAL_DELAY=2
readonly DATA_PLANE_RETRY_MAX_DELAY=30

VERBOSE=false
DRY_RUN=false
FORCE=false
NON_INTERACTIVE=false
ALLOW_INTERACTIVE_LOGIN=false
ASSIGN_RBAC=false
DETECT_CLIENT_IP=false
DISABLE_SHARED_KEY=true
NETWORK_MODE="${TF_BACKEND_NETWORK_MODE:-ip}"
CLIENT_IP="${TF_BACKEND_CLIENT_IP:-}"

SUBSCRIPTION_ID="${ARM_SUBSCRIPTION_ID:-${AZURE_SUBSCRIPTION_ID:-}}"
TENANT_ID="${ARM_TENANT_ID:-${AZURE_TENANT_ID:-}}"
RESOURCE_GROUP="${TF_BACKEND_RESOURCE_GROUP:-}"
STORAGE_ACCOUNT="${TF_BACKEND_STORAGE_ACCOUNT:-}"
LOCATION="${TF_BACKEND_LOCATION:-westeurope}"
PROJECT="${TF_BACKEND_PROJECT:-terraform}"
ENVIRONMENT="${TF_BACKEND_ENVIRONMENT:-dev}"
CONTAINER_NAME="${TF_BACKEND_CONTAINER_NAME:-tfstate}"
STATE_KEY="${TF_BACKEND_STATE_KEY:-}"
BACKEND_FILE="${TF_BACKEND_FILE:-backend.tf}"
BACKEND_CONFIG_FILE="${TF_BACKEND_CONFIG_FILE:-backend.hcl}"
SKU="${TF_BACKEND_SKU:-Standard_LRS}"
BLOB_RETENTION_DAYS="${TF_BACKEND_BLOB_RETENTION_DAYS:-14}"
CONTAINER_RETENTION_DAYS="${TF_BACKEND_CONTAINER_RETENTION_DAYS:-14}"
PRINCIPAL_OBJECT_ID="${TF_BACKEND_PRINCIPAL_OBJECT_ID:-}"
PRINCIPAL_TYPE="${TF_BACKEND_PRINCIPAL_TYPE:-}"

# User-supplied tags are parsed after all other arguments so defaults can be merged safely.
declare -a USER_TAGS=()
declare -A TAG_MAP=()
declare -a TEMP_FILES=()

STORAGE_WOULD_CREATE=false
STORAGE_RESOURCE_ID=""
CURRENT_IDENTITY_NAME=""
CURRENT_IDENTITY_TYPE=""

usage() {
  cat <<'USAGE'
Usage:
  terraform_setup [options]

Description:
  Creates or reconciles an Azure Storage backend for Terraform without
  retrieving Storage account keys. Azure Blob data operations use the current
  Microsoft Entra ID identity through Azure CLI (--auth-mode login).

Required context:
  An authenticated Azure CLI session is normally required. The script can
  optionally start an interactive user login with --login. Service-principal,
  managed-identity and OIDC authentication must be established before running
  the script (for example with Azure Login in CI).

Core options:
  --subscription-id ID       Target Azure subscription UUID.
  --tenant-id ID             Expected Microsoft Entra tenant UUID.
  --resource-group NAME      Backend resource group.
  --storage-account NAME     Explicit Storage account name (3-24 lowercase
                             letters or digits). Otherwise a stable name is
                             derived from subscription, project and environment.
  --location NAME            Azure region. Default: westeurope.
  --project NAME             Project identifier. Default: terraform.
  --environment NAME         Environment identifier. Default: dev.
  --container-name NAME      Blob container. Default: tfstate.
  --state-key NAME           Terraform state blob name. Default: <env>.tfstate.
  --sku NAME                 Storage SKU. Default: Standard_LRS.
  --tag KEY=VALUE            Merge one Azure tag. Repeatable.

Network options:
  --network-mode MODE        ip, open or disabled. Default: ip.
                               ip       Public endpoint restricted to CLIENT_IP.
                               open     Public endpoint enabled, default Allow.
                               disabled Public endpoint disabled after container
                                        creation; private connectivity is then
                                        required for subsequent Terraform use.
  --client-ip IPV4           Explicit public IPv4 address for ip mode.
  --detect-client-ip         Detect IPv4 from api.ipify.org with timeout/retries.
  --enable-ip-rule           Alias for --network-mode ip.
  --disable-ip-rule          Alias for --network-mode open. Existing rules are
                             preserved; this script never removes network rules.

Security and RBAC:
  --assign-rbac              Assign Storage Blob Data Contributor at Storage
                             account scope if it is not already assigned.
  --principal-object-id ID   Object ID used for RBAC checks/assignment.
  --principal-type TYPE      User or ServicePrincipal. Auto-detected when possible.
  --keep-shared-key-access   Do not disable Shared Key on an existing account;
                             new accounts will allow it. Entra auth remains used.
  --blob-retention-days N    Blob soft-delete retention, 1-365. Default: 14.
  --container-retention-days N
                             Container soft-delete retention, 1-365. Default: 14.

Generated files:
  --backend-file PATH        Terraform file containing backend "azurerm" {}.
                             Default: backend.tf.
  --backend-config-file PATH Non-secret backend configuration. Default: backend.hcl.
  --force                    Permit controlled incompatible changes (such as SKU
                             updates or disabling Shared Key on an existing
                             account) and overwrite differing generated files.

Execution controls:
  --login                    Permit an interactive az login if no session exists.
  --dry-run                  Read Azure state and print planned changes only.
                             No Azure resource mutation and no file write occurs.
  --non-interactive          Never start interactive authentication or prompts.
  --verbose                  Enable debug-level messages (never prints tokens).
  --help                     Show this help.

Environment variables:
  ARM_SUBSCRIPTION_ID, ARM_TENANT_ID,
  TF_BACKEND_RESOURCE_GROUP, TF_BACKEND_STORAGE_ACCOUNT,
  TF_BACKEND_LOCATION, TF_BACKEND_PROJECT, TF_BACKEND_ENVIRONMENT,
  TF_BACKEND_CONTAINER_NAME, TF_BACKEND_STATE_KEY,
  TF_BACKEND_FILE, TF_BACKEND_CONFIG_FILE, TF_BACKEND_SKU,
  TF_BACKEND_NETWORK_MODE, TF_BACKEND_CLIENT_IP,
  TF_BACKEND_BLOB_RETENTION_DAYS, TF_BACKEND_CONTAINER_RETENTION_DAYS,
  TF_BACKEND_PRINCIPAL_OBJECT_ID, TF_BACKEND_PRINCIPAL_TYPE.

Precedence:
  Command-line options > environment variables > non-sensitive defaults.

Examples:
  # Local run, explicitly allowing public IP detection
  ./terraform_setup \
    --subscription-id 00000000-0000-0000-0000-000000000000 \
    --tenant-id 11111111-1111-1111-1111-111111111111 \
    --project platform --environment dev \
    --network-mode ip --detect-client-ip --assign-rbac

  # Dry run with an explicit address
  ./terraform_setup \
    --subscription-id 00000000-0000-0000-0000-000000000000 \
    --client-ip 203.0.113.10 --dry-run

Terraform initialization:
  export ARM_USE_AZUREAD=true
  export ARM_USE_CLI=true
  terraform init -backend-config=backend.hcl

Permissions:
  Management plane: permission to read/create/update the resource group and
  Storage account. Data plane: Storage Blob Data Contributor or Owner.
  --assign-rbac additionally requires Microsoft.Authorization/roleAssignments/write
  (for example User Access Administrator, RBAC Administrator or Owner).
USAGE
}

now() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
info() { printf '%s [INFO]  %s\n' "$(now)" "$*" >&2; }
warn() { printf '%s [WARN]  %s\n' "$(now)" "$*" >&2; }
debug() { if [[ "$VERBOSE" == true ]]; then printf '%s [DEBUG] %s\n' "$(now)" "$*" >&2; fi; }
error() { printf '%s [ERROR] %s\n' "$(now)" "$*" >&2; }
die() { error "$*"; exit 1; }

cleanup() {
  local path
  for path in "${TEMP_FILES[@]:-}"; do
    if [[ -n "$path" && -e "$path" ]]; then
      rm -f -- "$path"
    fi
  done
  return 0
}

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  local command=${2:-unknown}
  error "Échec ligne ${line_no} (code ${exit_code}) pendant: ${command}"
  exit "$exit_code"
}

trap cleanup EXIT
trap 'on_error "$LINENO" "$BASH_COMMAND"' ERR

quote_cmd() {
  local item
  for item in "$@"; do printf '%q ' "$item"; done
  printf '\n'
}

run_mutation() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '%s [PLAN]  ' "$(now)" >&2
    quote_cmd "$@" >&2
    return 0
  fi
  debug "Exécution: $(quote_cmd "$@")"
  "$@"
}

normalize_storage_account_json() {
  local raw=$1 normalized
  if ! normalized=$(jq -ce '
    if type != "object" then error("root is not an object")
    elif ((has("location") | not) or (.location | type) != "string" or (.location | length) == 0) then error("location is missing or invalid")
    elif ((has("kind") | not) or (.kind | type) != "string" or (.kind | length) == 0) then error("kind is missing or invalid")
    elif ((has("sku") | not) or (.sku | type) != "object" or (.sku.name | type) != "string" or (.sku.name | length) == 0) then error("sku.name is missing or invalid")
    elif (has("enableHttpsTrafficOnly") | not) then error("enableHttpsTrafficOnly is missing")
    elif (has("minimumTlsVersion") | not) then error("minimumTlsVersion is missing")
    elif (has("allowBlobPublicAccess") | not) then error("allowBlobPublicAccess is missing")
    elif (has("allowSharedKeyAccess") | not) then error("allowSharedKeyAccess is missing")
    elif ((.enableHttpsTrafficOnly | type) != "boolean" and (.enableHttpsTrafficOnly | type) != "null") then error("enableHttpsTrafficOnly is invalid")
    elif ((.minimumTlsVersion | type) != "string" and (.minimumTlsVersion | type) != "null") then error("minimumTlsVersion is invalid")
    elif ((.minimumTlsVersion | type) == "string" and (.minimumTlsVersion | length) == 0) then error("minimumTlsVersion is empty")
    elif ((.allowBlobPublicAccess | type) != "boolean" and (.allowBlobPublicAccess | type) != "null") then error("allowBlobPublicAccess is invalid")
    elif ((.allowSharedKeyAccess | type) != "boolean" and (.allowSharedKeyAccess | type) != "null") then error("allowSharedKeyAccess is invalid")
    else {
      location: .location,
      kind: .kind,
      sku: .sku.name,
      https_only: .enableHttpsTrafficOnly,
      minimum_tls: .minimumTlsVersion,
      blob_public_access: .allowBlobPublicAccess,
      shared_key_access: .allowSharedKeyAccess
    }
    end
  ' <<< "$raw" 2>/dev/null); then
    error "Réponse JSON Azure invalide, incomplète ou inattendue pour le compte Storage."
    return 1
  fi
  printf '%s\n' "$normalized"
}

normalize_blob_service_json() {
  local raw=$1 normalized
  if ! normalized=$(jq -ce '
    if type != "object" then error("root is not an object")
    elif (has("isVersioningEnabled") | not) then error("isVersioningEnabled is missing")
    elif ((.isVersioningEnabled | type) != "boolean" and (.isVersioningEnabled | type) != "null") then error("isVersioningEnabled is invalid")
    elif ((.deleteRetentionPolicy | type) != "object") then error("deleteRetentionPolicy is missing or invalid")
    elif ((.containerDeleteRetentionPolicy | type) != "object") then error("containerDeleteRetentionPolicy is missing or invalid")
    elif ((.deleteRetentionPolicy | has("enabled")) | not) or ((.deleteRetentionPolicy | has("days")) | not) then error("deleteRetentionPolicy fields are missing")
    elif ((.containerDeleteRetentionPolicy | has("enabled")) | not) or ((.containerDeleteRetentionPolicy | has("days")) | not) then error("containerDeleteRetentionPolicy fields are missing")
    elif ((.deleteRetentionPolicy.enabled | type) != "boolean" and (.deleteRetentionPolicy.enabled | type) != "null") then error("deleteRetentionPolicy.enabled is invalid")
    elif ((.containerDeleteRetentionPolicy.enabled | type) != "boolean" and (.containerDeleteRetentionPolicy.enabled | type) != "null") then error("containerDeleteRetentionPolicy.enabled is invalid")
    elif ((.deleteRetentionPolicy.days | type) != "number" and (.deleteRetentionPolicy.days | type) != "null") then error("deleteRetentionPolicy.days is invalid")
    elif ((.containerDeleteRetentionPolicy.days | type) != "number" and (.containerDeleteRetentionPolicy.days | type) != "null") then error("containerDeleteRetentionPolicy.days is invalid")
    else {
      versioning: .isVersioningEnabled,
      blob_delete_enabled: .deleteRetentionPolicy.enabled,
      blob_delete_days: .deleteRetentionPolicy.days,
      container_delete_enabled: .containerDeleteRetentionPolicy.enabled,
      container_delete_days: .containerDeleteRetentionPolicy.days
    }
    end
  ' <<< "$raw" 2>/dev/null); then
    error "Réponse JSON Azure invalide, incomplète ou inattendue pour la protection Blob."
    return 1
  fi
  printf '%s\n' "$normalized"
}

normalize_network_json() {
  local raw=$1 normalized
  if ! normalized=$(jq -ce '
    if type != "object" then error("root is not an object")
    elif (has("publicNetworkAccess") | not) then error("publicNetworkAccess is missing")
    elif ((.networkRuleSet | type) != "object" or (.networkRuleSet | has("defaultAction") | not)) then error("networkRuleSet.defaultAction is missing")
    elif ((.publicNetworkAccess | type) != "string" and (.publicNetworkAccess | type) != "null") then error("publicNetworkAccess is invalid")
    elif ((.networkRuleSet.defaultAction | type) != "string" and (.networkRuleSet.defaultAction | type) != "null") then error("networkRuleSet.defaultAction is invalid")
    elif ((.publicNetworkAccess | type) == "string" and (.publicNetworkAccess | length) == 0) then error("publicNetworkAccess is empty")
    elif ((.networkRuleSet.defaultAction | type) == "string" and (.networkRuleSet.defaultAction | length) == 0) then error("networkRuleSet.defaultAction is empty")
    else {
      public_network_access: .publicNetworkAccess,
      default_action: .networkRuleSet.defaultAction
    }
    end
  ' <<< "$raw" 2>/dev/null); then
    error "Réponse JSON Azure invalide, incomplète ou inattendue pour les règles réseau Storage."
    return 1
  fi
  printf '%s\n' "$normalized"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Commande requise introuvable: $1"
}

version_ge() {
  local actual=$1 required=$2
  local -a a r
  local i max
  IFS=. read -r -a a <<< "${actual%%[^0-9.]*}"
  IFS=. read -r -a r <<< "$required"
  max=${#a[@]}
  (( ${#r[@]} > max )) && max=${#r[@]}
  for ((i=0; i<max; i++)); do
    local av=${a[i]:-0} rv=${r[i]:-0}
    ((10#$av > 10#$rv)) && return 0
    ((10#$av < 10#$rv)) && return 1
  done
  return 0
}

validate_bash_version() {
  if (( BASH_VERSINFO[0] < MIN_BASH_MAJOR )) ||
     (( BASH_VERSINFO[0] == MIN_BASH_MAJOR && BASH_VERSINFO[1] < MIN_BASH_MINOR )); then
    die "Bash ${MIN_BASH_MAJOR}.${MIN_BASH_MINOR}+ requis; version actuelle: ${BASH_VERSION}"
  fi
}

validate_uuid() {
  [[ "$1" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] ||
    die "$2 n'est pas un UUID valide: $1"
}

validate_resource_group() {
  local value=$1
  (( ${#value} >= 1 && ${#value} <= 90 )) || die "Nom de groupe de ressources invalide (1-90 caractères)."
  [[ "$value" =~ ^[[:alnum:]_.()-]+$ ]] || die "Caractères invalides dans le groupe de ressources: $value"
  [[ "$value" != *. ]] || die "Le groupe de ressources ne peut pas se terminer par un point."
}


validate_location_name() {
  [[ "$1" =~ ^[a-z0-9-]+$ ]] || die "Nom de région Azure invalide: $1"
}

validate_sku() {
  case "$1" in
    Standard_LRS|Standard_GRS|Standard_RAGRS|Standard_ZRS|Standard_GZRS|Standard_RAGZRS|    StandardV2_LRS|StandardV2_GRS|StandardV2_ZRS|StandardV2_GZRS|    Premium_LRS|Premium_ZRS|PremiumV2_LRS|PremiumV2_ZRS) ;;
    *) die "SKU Storage non pris en charge par ce script: $1" ;;
  esac
}

validate_path_value() {
  local value=$1 label=$2
  [[ -n "$value" ]] || die "$label ne peut pas être vide."
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die "$label contient un saut de ligne."
}

validate_storage_account() {
  [[ "$1" =~ ^[a-z0-9]{3,24}$ ]] ||
    die "Nom Storage invalide: 3-24 caractères, uniquement lettres minuscules et chiffres."
}

validate_container_name() {
  local value=$1
  [[ "$value" =~ ^[a-z0-9]([a-z0-9-]{1,61}[a-z0-9])?$ ]] ||
    die "Nom de conteneur invalide: 3-63 caractères minuscules/chiffres/tirets."
  [[ "$value" != *--* ]] || die "Le nom du conteneur ne peut pas contenir deux tirets consécutifs."
}

validate_state_key() {
  local value=$1
  [[ -n "$value" ]] || die "La clé Terraform state ne peut pas être vide."
  (( ${#value} <= 1024 )) || die "La clé Terraform state dépasse 1024 caractères."
  [[ "$value" != *$'\n'* && "$value" != *$'\r'* ]] || die "La clé Terraform state contient un saut de ligne."
}

validate_positive_days() {
  [[ "$1" =~ ^[0-9]+$ ]] || die "$2 doit être un entier."
  (( 10#$1 >= 1 && 10#$1 <= 365 )) || die "$2 doit être compris entre 1 et 365."
}

validate_ipv4() {
  local ip=$1 octet
  local -a octets
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "$ip"
  for octet in "${octets[@]}"; do
    ((10#$octet >= 0 && 10#$octet <= 255)) || return 1
  done
}

validate_tag() {
  local raw=$1 key value
  [[ "$raw" == *=* ]] || die "Tag invalide '$raw' (format attendu KEY=VALUE)."
  key=${raw%%=*}
  value=${raw#*=}
  [[ -n "$key" ]] || die "Clé de tag vide."
  (( ${#key} <= 128 )) || die "Clé de tag trop longue: $key"
  (( ${#value} <= 256 )) || die "Valeur de tag trop longue pour: $key"
  [[ "$key" =~ ^[A-Za-z0-9_.-]+$ ]] || die "Clé de tag invalide (lettres, chiffres, point, tiret, underscore uniquement): $key"
  [[ "$key" != *$'\n'* && "$value" != *$'\n'* ]] || die "Les tags ne peuvent pas contenir de saut de ligne."
}

hash_text() {
  local input=$1
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$input" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$input" | shasum -a 256 | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    printf '%s' "$input" | openssl dgst -sha256 | awk '{print $NF}'
  else
    die "sha256sum, shasum ou openssl est requis pour générer un nom déterministe."
  fi
}

normalize_alnum() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9'
}

normalize_rg_component() {
  local normalized
  normalized=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9._()-' '-')
  normalized=${normalized#-}
  normalized=${normalized%-}
  [[ -n "$normalized" ]] || normalized="terraform"
  printf '%s' "$normalized"
}

derive_storage_account_name() {
  local project_part env_part suffix result
  project_part=$(normalize_alnum "$PROJECT")
  env_part=$(normalize_alnum "$ENVIRONMENT")
  [[ -n "$project_part" ]] || project_part=tf
  [[ -n "$env_part" ]] || env_part="env"
  project_part=${project_part:0:8}
  env_part=${env_part:0:4}
  suffix=$(hash_text "${SUBSCRIPTION_ID}|${PROJECT}|${ENVIRONMENT}")
  result="tf${project_part}${env_part}${suffix:0:10}"
  printf '%s' "${result:0:24}"
}

hcl_escape() {
  local value=$1
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "$value"
}

parse_args() {
  while (($#)); do
    case "$1" in
      --subscription-id) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; SUBSCRIPTION_ID=$2; shift 2 ;;
      --tenant-id) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; TENANT_ID=$2; shift 2 ;;
      --resource-group) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; RESOURCE_GROUP=$2; shift 2 ;;
      --storage-account) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; STORAGE_ACCOUNT=$2; shift 2 ;;
      --location) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; LOCATION=$2; shift 2 ;;
      --project) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; PROJECT=$2; shift 2 ;;
      --environment) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; ENVIRONMENT=$2; shift 2 ;;
      --container-name) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; CONTAINER_NAME=$2; shift 2 ;;
      --state-key) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; STATE_KEY=$2; shift 2 ;;
      --backend-file) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; BACKEND_FILE=$2; shift 2 ;;
      --backend-config-file) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; BACKEND_CONFIG_FILE=$2; shift 2 ;;
      --sku) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; SKU=$2; shift 2 ;;
      --tag) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; USER_TAGS+=("$2"); shift 2 ;;
      --network-mode) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; NETWORK_MODE=$2; shift 2 ;;
      --client-ip) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; CLIENT_IP=$2; shift 2 ;;
      --detect-client-ip) DETECT_CLIENT_IP=true; shift ;;
      --enable-ip-rule) NETWORK_MODE=ip; shift ;;
      --disable-ip-rule) NETWORK_MODE=open; shift ;;
      --assign-rbac) ASSIGN_RBAC=true; shift ;;
      --principal-object-id) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; PRINCIPAL_OBJECT_ID=$2; shift 2 ;;
      --principal-type) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; PRINCIPAL_TYPE=$2; shift 2 ;;
      --keep-shared-key-access) DISABLE_SHARED_KEY=false; shift ;;
      --blob-retention-days) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; BLOB_RETENTION_DAYS=$2; shift 2 ;;
      --container-retention-days) [[ $# -ge 2 ]] || die "Valeur manquante pour $1"; CONTAINER_RETENTION_DAYS=$2; shift 2 ;;
      --login) ALLOW_INTERACTIVE_LOGIN=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      --force) FORCE=true; shift ;;
      --non-interactive) NON_INTERACTIVE=true; shift ;;
      --verbose) VERBOSE=true; shift ;;
      --help|-h) usage; exit 0 ;;
      --) shift; break ;;
      *) die "Argument inconnu: $1" ;;
    esac
  done
  (($# == 0)) || die "Arguments positionnels non pris en charge: $*"
}

finalize_defaults_and_validate() {
  [[ "$NETWORK_MODE" =~ ^(ip|open|disabled)$ ]] || die "--network-mode doit être ip, open ou disabled."
  [[ -n "$PROJECT" && -n "$ENVIRONMENT" ]] || die "Project et environment ne peuvent pas être vides."

  if [[ -z "$RESOURCE_GROUP" ]]; then
    RESOURCE_GROUP="rg-$(normalize_rg_component "$PROJECT")-$(normalize_rg_component "$ENVIRONMENT")-tfstate"
  fi
  if [[ -z "$STATE_KEY" ]]; then
    STATE_KEY="${ENVIRONMENT}.tfstate"
  fi

  validate_resource_group "$RESOURCE_GROUP"
  validate_location_name "$LOCATION"
  validate_sku "$SKU"
  validate_container_name "$CONTAINER_NAME"
  validate_state_key "$STATE_KEY"
  validate_positive_days "$BLOB_RETENTION_DAYS" "--blob-retention-days"
  validate_positive_days "$CONTAINER_RETENTION_DAYS" "--container-retention-days"
  validate_path_value "$BACKEND_FILE" "--backend-file"
  validate_path_value "$BACKEND_CONFIG_FILE" "--backend-config-file"
  [[ "$BACKEND_FILE" != "$BACKEND_CONFIG_FILE" ]] || die "backend.tf et backend.hcl doivent être deux fichiers distincts."

  case "$PRINCIPAL_TYPE" in
    ""|User|ServicePrincipal) ;;
    user) PRINCIPAL_TYPE=User ;;
    servicePrincipal|serviceprincipal) PRINCIPAL_TYPE=ServicePrincipal ;;
    *) die "--principal-type doit être User ou ServicePrincipal." ;;
  esac

  if [[ -n "$CLIENT_IP" ]] && ! validate_ipv4 "$CLIENT_IP"; then
    die "Adresse IPv4 invalide: $CLIENT_IP"
  fi
  if [[ "$NETWORK_MODE" == ip && -z "$CLIENT_IP" && "$DETECT_CLIENT_IP" != true ]]; then
    die "Le mode ip exige --client-ip ou --detect-client-ip (appel externe explicite)."
  fi

  TAG_MAP[environment]=$ENVIRONMENT
  TAG_MAP[project]=$PROJECT
  TAG_MAP[purpose]=terraform-state
  local raw key value
  for raw in "${USER_TAGS[@]}"; do
    validate_tag "$raw"
    key=${raw%%=*}
    value=${raw#*=}
    TAG_MAP["$key"]=$value
  done
}

preflight() {
  validate_bash_version
  require_command az
  if [[ "$DETECT_CLIENT_IP" == true ]]; then require_command curl; fi
  require_command diff
  require_command mktemp
  require_command sort
  require_command awk
  require_command tr
  require_command jq

  local az_version
  az_version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || true)
  [[ -n "$az_version" ]] || die "Impossible de déterminer la version Azure CLI."
  version_ge "$az_version" "$MIN_AZ_CLI_VERSION" ||
    die "Azure CLI ${MIN_AZ_CLI_VERSION}+ requis; version actuelle: $az_version"
  info "Préflight validé: Bash ${BASH_VERSION%%(*}, Azure CLI $az_version"
}

ensure_azure_session() {
  local current_subscription current_tenant
  if ! az account show --only-show-errors -o json >/dev/null 2>&1; then
    if [[ "$ALLOW_INTERACTIVE_LOGIN" == true && "$NON_INTERACTIVE" != true ]]; then
      local -a login_cmd=(az login --only-show-errors)
      [[ -n "$TENANT_ID" ]] && login_cmd+=(--tenant "$TENANT_ID")
      info "Aucune session Azure CLI valide; ouverture d'une connexion interactive autorisée."
      "${login_cmd[@]}" >/dev/null
    else
      die "Aucune session Azure CLI valide. Authentifie az en amont ou utilise --login en mode interactif."
    fi
  fi

  if [[ -n "$SUBSCRIPTION_ID" ]]; then
    validate_uuid "$SUBSCRIPTION_ID" "Subscription ID"
    az account set --subscription "$SUBSCRIPTION_ID" --only-show-errors
  fi

  current_subscription=$(az account show --query id -o tsv --only-show-errors)
  current_tenant=$(az account show --query tenantId -o tsv --only-show-errors)
  CURRENT_IDENTITY_NAME=$(az account show --query user.name -o tsv --only-show-errors)
  CURRENT_IDENTITY_TYPE=$(az account show --query user.type -o tsv --only-show-errors)

  [[ -n "$SUBSCRIPTION_ID" ]] || SUBSCRIPTION_ID=$current_subscription
  [[ -n "$TENANT_ID" ]] || TENANT_ID=$current_tenant
  validate_uuid "$SUBSCRIPTION_ID" "Subscription ID"
  validate_uuid "$TENANT_ID" "Tenant ID"

  [[ "${current_subscription,,}" == "${SUBSCRIPTION_ID,,}" ]] ||
    die "Abonnement actif inattendu: $current_subscription (attendu: $SUBSCRIPTION_ID)."
  [[ "${current_tenant,,}" == "${TENANT_ID,,}" ]] ||
    die "Tenant actif inattendu: $current_tenant (attendu: $TENANT_ID)."

  info "Contexte Azure: abonnement $SUBSCRIPTION_ID, tenant $TENANT_ID, identité ${CURRENT_IDENTITY_NAME:-inconnue} (${CURRENT_IDENTITY_TYPE:-inconnue})"
}

validate_location_online() {
  local count
  count=$(az account list-locations --query "[?name=='${LOCATION}'] | length(@)" -o tsv --only-show-errors)
  [[ "$count" != 0 ]] || die "Région Azure inconnue ou indisponible dans l'abonnement: $LOCATION"
}

detect_client_ip() {
  [[ "$NETWORK_MODE" == ip ]] || return 0
  [[ -z "$CLIENT_IP" ]] || return 0
  info "Détection explicite de l'adresse IPv4 publique via api.ipify.org."
  CLIENT_IP=$(curl --fail --silent --show-error --location \
    --connect-timeout 3 --max-time 8 --retry 2 --retry-delay 1 \
    https://api.ipify.org)
  CLIENT_IP=${CLIENT_IP//$'\r'/}
  CLIENT_IP=${CLIENT_IP//$'\n'/}
  validate_ipv4 "$CLIENT_IP" || die "Le service d'IP a retourné une valeur IPv4 invalide."
  info "Adresse IPv4 détectée: $CLIENT_IP"
}

build_tag_args() {
  local -n output=$1
  local key
  local -a keys=()
  mapfile -t keys < <(printf '%s\n' "${!TAG_MAP[@]}" | sort)
  output=()
  for key in "${keys[@]}"; do output+=("${key}=${TAG_MAP[$key]}"); done
}

merge_tags() {
  local resource_id=$1 description=$2
  local -a tags=() keys=()
  local key current changed=false
  build_tag_args tags
  if [[ ${#tags[@]} -eq 0 ]]; then return 0; fi
  mapfile -t keys < <(printf '%s\n' "${!TAG_MAP[@]}" | sort)
  for key in "${keys[@]}"; do
    current=$(az tag list --resource-id "$resource_id" \
      --query "properties.tags.\"${key}\"" -o tsv --only-show-errors 2>/dev/null || true)
    if [[ "$current" != "${TAG_MAP[$key]}" ]]; then
      changed=true
      break
    fi
  done
  if [[ "$changed" != true ]]; then
    info "Tags déjà conformes: $description"
    return 0
  fi
  info "Réconciliation non destructive des tags: $description"
  run_mutation az tag update --resource-id "$resource_id" --operation Merge \
    --tags "${tags[@]}" --only-show-errors --output none
}

ensure_resource_group() {
  local exists rg_location rg_id
  exists=$(az group exists --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" -o tsv)
  if [[ "$exists" == true ]]; then
    rg_location=$(az group show --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" --query location -o tsv --only-show-errors)
    rg_id=$(az group show --name "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" --query id -o tsv --only-show-errors)
    info "Groupe de ressources existant: $RESOURCE_GROUP (métadonnées: $rg_location)"
    if [[ "${rg_location,,}" != "${LOCATION,,}" ]]; then
      warn "Le groupe existe dans '$rg_location'. Sa région de métadonnées est immuable, mais les ressources peuvent être créées dans '$LOCATION'."
    fi
    merge_tags "$rg_id" "groupe de ressources $RESOURCE_GROUP"
  else
    local -a tags=()
    build_tag_args tags
    info "Création du groupe de ressources: $RESOURCE_GROUP"
    run_mutation az group create --name "$RESOURCE_GROUP" --location "$LOCATION" \
      --subscription "$SUBSCRIPTION_ID" --tags "${tags[@]}" --only-show-errors --output none
  fi
}

storage_exists_in_target() {
  az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" --only-show-errors --output none 2>/dev/null
}

check_storage_name_conflict() {
  local same_subscription available reason message
  same_subscription=$(az storage account list --subscription "$SUBSCRIPTION_ID" \
    --query "[?name=='${STORAGE_ACCOUNT}'].resourceGroup | [0]" -o tsv --only-show-errors)
  if [[ -n "$same_subscription" && "$same_subscription" != "$RESOURCE_GROUP" ]]; then
    die "Le compte '$STORAGE_ACCOUNT' existe déjà dans le groupe '$same_subscription' du même abonnement."
  fi
  available=$(az storage account check-name --name "$STORAGE_ACCOUNT" --query nameAvailable -o tsv --only-show-errors)
  if [[ "$available" != true ]]; then
    reason=$(az storage account check-name --name "$STORAGE_ACCOUNT" --query reason -o tsv --only-show-errors)
    message=$(az storage account check-name --name "$STORAGE_ACCOUNT" --query message -o tsv --only-show-errors)
    die "Nom Storage indisponible globalement ($reason): $message"
  fi
}

create_storage_account() {
  local -a tags=()
  build_tag_args tags
  local shared_key=true
  [[ "$DISABLE_SHARED_KEY" == true ]] && shared_key=false
  info "Création sécurisée du compte Storage: $STORAGE_ACCOUNT"
  run_mutation az storage account create \
    --name "$STORAGE_ACCOUNT" \
    --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" \
    --location "$LOCATION" \
    --kind StorageV2 \
    --sku "$SKU" \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-shared-key-access "$shared_key" \
    --public-network-access Enabled \
    --default-action Allow \
    --bypass None \
    --tags "${tags[@]}" \
    --only-show-errors --output none
}

storage_account_properties_json() {
  local raw
  if ! raw=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" --output json --only-show-errors); then
    error "Azure CLI n'a pas pu lire les propriétés du compte Storage '$STORAGE_ACCOUNT'."
    return 1
  fi
  normalize_storage_account_json "$raw"
}

reconcile_existing_storage() {
  local properties existing_location existing_kind existing_sku https_only min_tls blob_public shared_key
  properties=$(storage_account_properties_json) ||
    die "Impossible de réconcilier le compte Storage sans propriétés structurées valides."
  existing_location=$(jq -r '.location' <<< "$properties")
  existing_kind=$(jq -r '.kind' <<< "$properties")
  existing_sku=$(jq -r '.sku' <<< "$properties")
  https_only=$(jq -r 'if .https_only == null then "null" else (.https_only | tostring) end' <<< "$properties")
  min_tls=$(jq -r 'if .minimum_tls == null then "null" else .minimum_tls end' <<< "$properties")
  blob_public=$(jq -r 'if .blob_public_access == null then "null" else (.blob_public_access | tostring) end' <<< "$properties")
  shared_key=$(jq -r 'if .shared_key_access == null then "null" else (.shared_key_access | tostring) end' <<< "$properties")

  [[ "${existing_location,,}" == "${LOCATION,,}" ]] ||
    die "Compte Storage incompatible: région '$existing_location', attendue '$LOCATION'. La région ne peut pas être modifiée."
  [[ "$existing_kind" == StorageV2 ]] ||
    die "Compte Storage incompatible: kind '$existing_kind'. Une migration explicite vers StorageV2 est requise."

  local -a update=(az storage account update --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID")
  local changed=false

  if [[ "$existing_sku" != "$SKU" ]]; then
    [[ "$FORCE" == true ]] || die "SKU existant '$existing_sku' différent de '$SKU'. Relance avec --force après vérification de compatibilité."
    update+=(--sku "$SKU")
    changed=true
  fi
  if [[ "$https_only" != true ]]; then update+=(--https-only true); changed=true; fi
  if [[ "$min_tls" != TLS1_2 && "$min_tls" != TLS1_3 ]]; then update+=(--min-tls-version TLS1_2); changed=true; fi
  if [[ "$blob_public" != false ]]; then update+=(--allow-blob-public-access false); changed=true; fi

  if [[ "$DISABLE_SHARED_KEY" == true && "$shared_key" != false ]]; then
    [[ "$FORCE" == true ]] || die "Shared Key est encore autorisé sur le compte existant. Utilise --force pour le désactiver, ou --keep-shared-key-access pour conserver l'état."
    update+=(--allow-shared-key-access false)
    changed=true
  fi

  if [[ "$changed" == true ]]; then
    info "Mise en conformité des propriétés du compte Storage."
    update+=(--only-show-errors --output none)
    run_mutation "${update[@]}"
  else
    info "Propriétés principales du compte Storage déjà conformes."
  fi

  STORAGE_RESOURCE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" --query id -o tsv --only-show-errors)
  merge_tags "$STORAGE_RESOURCE_ID" "compte Storage $STORAGE_ACCOUNT"
}

ensure_storage_account() {
  if [[ -z "$STORAGE_ACCOUNT" ]]; then
    STORAGE_ACCOUNT=$(derive_storage_account_name)
  fi
  validate_storage_account "$STORAGE_ACCOUNT"
  info "Nom Storage cible: $STORAGE_ACCOUNT"

  if storage_exists_in_target; then
    info "Compte Storage existant trouvé dans le groupe cible."
    reconcile_existing_storage
  else
    check_storage_name_conflict
    if [[ "$DRY_RUN" == true ]]; then
      STORAGE_WOULD_CREATE=true
      STORAGE_RESOURCE_ID="/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT}"
      create_storage_account
    else
      create_storage_account
      STORAGE_RESOURCE_ID=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
        --subscription "$SUBSCRIPTION_ID" --query id -o tsv --only-show-errors)
    fi
  fi
}

blob_service_properties_json() {
  local raw
  if ! raw=$(az storage account blob-service-properties show \
    --account-name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
    --output json --only-show-errors); then
    error "Azure CLI n'a pas pu lire les propriétés de protection Blob du compte '$STORAGE_ACCOUNT'."
    return 1
  fi
  normalize_blob_service_json "$raw"
}

reconcile_blob_protection() {
  if [[ "$STORAGE_WOULD_CREATE" == true ]]; then
    info "[PLAN] Activation du versioning et des suppressions réversibles Blob/conteneur."
    return 0
  fi

  local properties versioning delete_enabled delete_days container_enabled container_days
  properties=$(blob_service_properties_json) ||
    die "Impossible de réconcilier la protection Blob sans propriétés structurées valides."
  versioning=$(jq -r 'if .versioning == null then "null" else (.versioning | tostring) end' <<< "$properties")
  delete_enabled=$(jq -r 'if .blob_delete_enabled == null then "null" else (.blob_delete_enabled | tostring) end' <<< "$properties")
  delete_days=$(jq -r 'if .blob_delete_days == null then "null" else (.blob_delete_days | tostring) end' <<< "$properties")
  container_enabled=$(jq -r 'if .container_delete_enabled == null then "null" else (.container_delete_enabled | tostring) end' <<< "$properties")
  container_days=$(jq -r 'if .container_delete_days == null then "null" else (.container_delete_days | tostring) end' <<< "$properties")

  if [[ "$versioning" == true && "$delete_enabled" == true && "$delete_days" == "$BLOB_RETENTION_DAYS" &&
        "$container_enabled" == true && "$container_days" == "$CONTAINER_RETENTION_DAYS" ]]; then
    info "Protection des données Blob déjà conforme."
    return 0
  fi

  info "Activation/réconciliation du versioning et des suppressions réversibles."
  run_mutation az storage account blob-service-properties update \
    --account-name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
    --enable-versioning true \
    --enable-delete-retention true --delete-retention-days "$BLOB_RETENTION_DAYS" \
    --enable-container-delete-retention true --container-delete-retention-days "$CONTAINER_RETENTION_DAYS" \
    --only-show-errors --output none
}

network_values() {
  local raw
  if ! raw=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" --output json --only-show-errors); then
    error "Azure CLI n'a pas pu lire les propriétés réseau du compte Storage '$STORAGE_ACCOUNT'."
    return 1
  fi
  normalize_network_json "$raw"
}

ip_rule_exists() {
  local rules
  rules=$(az storage account network-rule list --account-name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" --query 'ipRules[].ipAddressOrRange' -o tsv --only-show-errors)
  grep -Fxq -- "$CLIENT_IP" <<< "$rules"
}

reconcile_network_before_container() {
  if [[ "$STORAGE_WOULD_CREATE" == true ]]; then
    case "$NETWORK_MODE" in
      ip)
        info "[PLAN] Ajout de l'IPv4 $CLIENT_IP, puis default-action Deny sur le point de terminaison public."
        ;;
      open)
        info "[PLAN] Maintien du point de terminaison public avec default-action Allow."
        ;;
      disabled)
        info "[PLAN] Le point de terminaison public restera temporairement ouvert pour créer le conteneur, puis sera désactivé."
        ;;
    esac
    return 0
  fi

  local properties public_network default_action
  properties=$(network_values) || die "Impossible de réconcilier le réseau Storage sans propriétés structurées valides."
  public_network=$(jq -r 'if .public_network_access == null then "null" else .public_network_access end' <<< "$properties")
  default_action=$(jq -r 'if .default_action == null then "null" else .default_action end' <<< "$properties")
  [[ "$public_network" != null && "$public_network" != None ]] || public_network=Enabled

  case "$NETWORK_MODE" in
    ip)
      if [[ "$public_network" != Enabled ]]; then
        info "Activation du point de terminaison public pour le mode IP restreint."
        run_mutation az storage account update --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
          --subscription "$SUBSCRIPTION_ID" --public-network-access Enabled --only-show-errors --output none
      fi
      if ip_rule_exists; then
        info "Règle IP déjà présente: $CLIENT_IP"
      else
        info "Ajout de la règle IPv4: $CLIENT_IP"
        run_mutation az storage account network-rule add --account-name "$STORAGE_ACCOUNT" \
          --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID" \
          --action Allow --ip-address "$CLIENT_IP" --only-show-errors --output none
      fi
      if [[ "$default_action" != Deny ]]; then
        info "Activation du filtrage réseau par défaut (Deny) après ajout de la règle."
        run_mutation az storage account update --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
          --subscription "$SUBSCRIPTION_ID" --default-action Deny --only-show-errors --output none
      fi
      ;;
    open)
      local -a update=(az storage account update --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --subscription "$SUBSCRIPTION_ID")
      local changed=false
      if [[ "$public_network" != Enabled ]]; then update+=(--public-network-access Enabled); changed=true; fi
      if [[ "$default_action" != Allow ]]; then update+=(--default-action Allow); changed=true; fi
      if [[ "$changed" == true ]]; then
        warn "Mode open demandé: le point de terminaison public autorisera tous les réseaux."
        update+=(--only-show-errors --output none)
        run_mutation "${update[@]}"
      else
        info "Configuration réseau open déjà conforme."
      fi
      ;;
    disabled)
      if [[ "$public_network" == Disabled ]]; then
        info "Accès réseau public déjà désactivé; le test data plane exigera une connectivité privée existante."
      else
        info "La désactivation réseau sera appliquée après la création/vérification du conteneur."
      fi
      ;;
  esac
}

reconcile_network_after_container() {
  [[ "$NETWORK_MODE" == disabled ]] || return 0
  if [[ "$STORAGE_WOULD_CREATE" == true ]]; then
    info "[PLAN] Désactivation finale de l'accès réseau public."
    return 0
  fi
  local properties public_network default_action
  properties=$(network_values) || die "Impossible de vérifier le réseau Storage sans propriétés structurées valides."
  public_network=$(jq -r 'if .public_network_access == null then "null" else .public_network_access end' <<< "$properties")
  default_action=$(jq -r 'if .default_action == null then "null" else .default_action end' <<< "$properties")
  if [[ "$public_network" == Disabled && "$default_action" == Deny ]]; then
    info "Accès réseau public déjà désactivé."
    return 0
  fi
  warn "Désactivation de l'accès réseau public. Terraform nécessitera un private endpoint/connectivité privée."
  run_mutation az storage account update --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
    --subscription "$SUBSCRIPTION_ID" --default-action Deny --public-network-access Disabled \
    --only-show-errors --output none
}

resolve_principal() {
  if [[ -n "$PRINCIPAL_OBJECT_ID" ]]; then
    validate_uuid "$PRINCIPAL_OBJECT_ID" "Principal object ID"
    [[ -n "$PRINCIPAL_TYPE" ]] || PRINCIPAL_TYPE=ServicePrincipal
    return 0
  fi

  case "${CURRENT_IDENTITY_TYPE,,}" in
    user)
      PRINCIPAL_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv --only-show-errors 2>/dev/null || true)
      PRINCIPAL_TYPE=User
      ;;
    serviceprincipal|managedidentity)
      PRINCIPAL_OBJECT_ID=$(az ad sp show --id "$CURRENT_IDENTITY_NAME" --query id -o tsv --only-show-errors 2>/dev/null || true)
      PRINCIPAL_TYPE=ServicePrincipal
      ;;
  esac

  if [[ -z "$PRINCIPAL_OBJECT_ID" ]]; then
    if [[ "$ASSIGN_RBAC" == true ]]; then
      die "Impossible de résoudre l'Object ID de l'identité. Fournis --principal-object-id et --principal-type."
    fi
    warn "Object ID non résolu; la vérification RBAC sera remplacée par un test data plane direct."
    return 0
  fi
  validate_uuid "$PRINCIPAL_OBJECT_ID" "Principal object ID"
  info "Principal RBAC résolu ($PRINCIPAL_TYPE); Object ID masqué."
}

count_effective_role_assignments_json() {
  local raw=$1 role=$2 target_scope=$3 count
  if ! count=$(jq -er --arg role "$role" --arg target "$target_scope" '
    def norm: ascii_downcase | sub("/+$"; "");
    if type != "array" then error("root is not an array")
    else [
      .[]
      | select(type == "object")
      | select(.roleDefinitionName? == $role)
      | select(((.principalId? | type) == "string") and ((.principalId | length) > 0))
      | select(((.scope? | type) == "string") and ((.scope | length) > 0))
      | select(
          (.scope | norm) as $assignment_scope
          | ($target | norm) as $target_scope
          | ($assignment_scope == "/")
            or ($target_scope == $assignment_scope)
            or ($target_scope | startswith($assignment_scope + "/"))
        )
    ] | length
    end
  ' <<< "$raw" 2>/dev/null); then
    error "Réponse JSON Azure invalide ou inattendue pendant la vérification RBAC."
    return 1
  fi
  printf '%s\n' "$count"
}

role_assignment_count() {
  local role=$1 raw
  local -a cmd=(az role assignment list --include-inherited
    --assignee-object-id "$PRINCIPAL_OBJECT_ID" --scope "$STORAGE_RESOURCE_ID"
    --role "$role" --fill-principal-name false --fill-role-definition-name true
    --output json --only-show-errors)
  if [[ "$PRINCIPAL_TYPE" == User ]]; then cmd+=(--include-groups); fi
  if ! raw=$("${cmd[@]}"); then
    error "Azure CLI n'a pas pu lister les attributions RBAC au scope demandé."
    return 1
  fi
  count_effective_role_assignments_json "$raw" "$role" "$STORAGE_RESOURCE_ID"
}

ensure_rbac() {
  resolve_principal
  if [[ "$STORAGE_WOULD_CREATE" == true ]]; then
    if [[ "$ASSIGN_RBAC" == true ]]; then
      info "[PLAN] Attribution de '$STORAGE_BLOB_DATA_CONTRIBUTOR' au principal configuré sur le compte Storage."
    else
      warn "[PLAN] Aucune attribution RBAC automatique; l'identité devra déjà avoir un rôle Blob data approprié."
    fi
    return 0
  fi

  [[ -n "$PRINCIPAL_OBJECT_ID" ]] || return 0
  local contributor owner total
  if ! contributor=$(role_assignment_count "$STORAGE_BLOB_DATA_CONTRIBUTOR" 2>/dev/null); then
    if [[ "$ASSIGN_RBAC" == true ]]; then
      die "Impossible de lister les rôles RBAC; refus de créer une attribution potentiellement dupliquée."
    fi
    warn "Impossible de lister les rôles RBAC; utilisation du test data plane direct."
    return 0
  fi
  if ! owner=$(role_assignment_count "$STORAGE_BLOB_DATA_OWNER" 2>/dev/null); then
    owner=0
  fi
  contributor=${contributor:-0}
  owner=${owner:-0}
  total=$((10#$contributor + 10#$owner))
  if (( total > 0 )); then
    info "Attribution Blob data suffisante détectée (directe ou héritée)."
    return 0
  fi

  if [[ "$ASSIGN_RBAC" != true ]]; then
    warn "Aucun rôle Blob data direct/hérité détecté. Le test data plane déterminera l'accès effectif."
    return 0
  fi

  if container_exists_call >/dev/null 2>&1; then
    info "Accès data plane effectif confirmé; aucune attribution RBAC supplémentaire n'est créée."
    return 0
  fi

  info "Attribution du rôle '$STORAGE_BLOB_DATA_CONTRIBUTOR' au scope du compte Storage."
  run_mutation az role assignment create \
    --assignee-object-id "$PRINCIPAL_OBJECT_ID" \
    --assignee-principal-type "$PRINCIPAL_TYPE" \
    --role "$STORAGE_BLOB_DATA_CONTRIBUTOR" \
    --scope "$STORAGE_RESOURCE_ID" \
    --only-show-errors --output none
}

container_exists_call() {
  az storage container exists --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login --timeout 10 --query exists -o tsv --only-show-errors
}

retry_container_access() {
  local attempts=${1:-8} delay=${2:-2} max_delay=${3:-15}
  local i output
  for ((i=1; i<=attempts; i++)); do
    if output=$(container_exists_call 2>/dev/null); then
      printf '%s' "$output"
      return 0
    fi
    if (( i < attempts )); then
      warn "Data plane Blob indisponible (tentative $i/$attempts); nouvel essai dans ${delay}s."
      sleep "$delay"
      (( delay < max_delay )) && delay=$((delay * 2))
      (( delay > max_delay )) && delay=$max_delay
    fi
  done
  return 1
}

ensure_container() {
  if [[ "$STORAGE_WOULD_CREATE" == true ]]; then
    info "[PLAN] Création du conteneur privé '$CONTAINER_NAME' avec Microsoft Entra ID."
    return 0
  fi

  local exists
  if ! exists=$(retry_container_access "$DATA_PLANE_RETRY_ATTEMPTS" "$DATA_PLANE_RETRY_INITIAL_DELAY" "$DATA_PLANE_RETRY_MAX_DELAY"); then
    die "Accès Blob refusé ou réseau indisponible. Vérifie le firewall/private endpoint et attribue '$STORAGE_BLOB_DATA_CONTRIBUTOR' à l'identité."
  fi
  if [[ "$exists" == true ]]; then
    info "Conteneur existant: $CONTAINER_NAME"
    return 0
  fi

  info "Création du conteneur privé avec --auth-mode login: $CONTAINER_NAME"
  run_mutation az storage container create --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT" \
    --auth-mode login --public-access off --timeout 30 --only-show-errors --output none
}

generate_backend_tf_content() {
  cat <<'EOF'
# Generated by terraform_setup. No credentials are stored here.
terraform {
  backend "azurerm" {}
}
EOF
}

generate_backend_hcl_content() {
  cat <<EOF
# Generated by terraform_setup. This file contains no secret.
use_azuread_auth     = true
subscription_id      = "$(hcl_escape "$SUBSCRIPTION_ID")"
tenant_id            = "$(hcl_escape "$TENANT_ID")"
resource_group_name  = "$(hcl_escape "$RESOURCE_GROUP")"
storage_account_name = "$(hcl_escape "$STORAGE_ACCOUNT")"
container_name       = "$(hcl_escape "$CONTAINER_NAME")"
key                  = "$(hcl_escape "$STATE_KEY")"
EOF
}

show_diff() {
  local path=$1 expected=$2 temp
  temp=$(mktemp "${TMPDIR:-/tmp}/${SCRIPT_NAME}.expected.XXXXXX")
  TEMP_FILES+=("$temp")
  printf '%s' "$expected" > "$temp"
  diff -u -- "$path" "$temp" || true
}

write_managed_file() {
  local path=$1 content=$2 description=$3
  local dir temp
  dir=$(dirname -- "$path")
  [[ -d "$dir" ]] || die "Répertoire de sortie inexistant: $dir"
  [[ -w "$dir" ]] || die "Répertoire de sortie non inscriptible: $dir"

  if [[ -e "$path" ]]; then
    if [[ "$(cat -- "$path")" == "${content%$'\n'}" ]]; then
      info "$description déjà identique: $path"
      return 0
    fi
    warn "$description existant différent: $path"
    show_diff "$path" "$content"
    if [[ "$DRY_RUN" == true ]]; then
      info "[PLAN] Le fichier différent serait remplacé avec --force: $path"
      return 0
    fi
    [[ "$FORCE" == true ]] || die "Refus d'écraser '$path' sans --force."
  fi

  if [[ "$DRY_RUN" == true ]]; then
    info "[PLAN] Écriture atomique de $description: $path"
    return 0
  fi

  temp=$(mktemp "${path}.tmp.XXXXXX")
  TEMP_FILES+=("$temp")
  printf '%s' "$content" > "$temp"
  chmod 0644 "$temp"
  mv -f -- "$temp" "$path"
  info "$description écrit atomiquement: $path"
}

generate_backend_files() {
  local tf_content hcl_content
  tf_content=$(generate_backend_tf_content)
  tf_content+=$'\n'
  hcl_content=$(generate_backend_hcl_content)
  hcl_content+=$'\n'
  write_managed_file "$BACKEND_FILE" "$tf_content" "configuration Terraform backend"
  write_managed_file "$BACKEND_CONFIG_FILE" "$hcl_content" "paramètres backend AzureRM"
}

summary() {
  cat >&2 <<EOF

Résumé de convergence
---------------------
Subscription : configurée (identifiant masqué)
Tenant       : configuré (identifiant masqué)
Resource grp : $RESOURCE_GROUP
Storage      : $STORAGE_ACCOUNT
Container    : $CONTAINER_NAME
State key    : $STATE_KEY
Location     : $LOCATION
SKU          : $SKU
Network mode : $NETWORK_MODE${CLIENT_IP:+ (IPv4 configurée, valeur masquée)}
Backend file : $BACKEND_FILE
Backend HCL  : $BACKEND_CONFIG_FILE
Dry-run      : $DRY_RUN

Initialisation Terraform locale:
  export ARM_USE_AZUREAD=true
  export ARM_USE_CLI=true
  terraform init -backend-config="$BACKEND_CONFIG_FILE"

CI OIDC (principe):
  ARM_USE_AZUREAD=true, ARM_USE_OIDC=true, ARM_CLIENT_ID, ARM_TENANT_ID,
  ARM_SUBSCRIPTION_ID, puis terraform init -backend-config="$BACKEND_CONFIG_FILE"
EOF
}

main() {
  parse_args "$@"
  preflight
  ensure_azure_session
  finalize_defaults_and_validate
  validate_location_online
  detect_client_ip
  ensure_resource_group
  ensure_storage_account
  reconcile_blob_protection
  reconcile_network_before_container
  ensure_rbac
  ensure_container
  reconcile_network_after_container
  generate_backend_files
  summary
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
