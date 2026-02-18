#!/usr/bin/env bash
#
# version-bump.sh - Bump VERSION files for services
#
# Usage:
#   ./scripts/version-bump.sh <service-path> <bump-type>
#   ./scripts/version-bump.sh apps/dashboard patch
#   ./scripts/version-bump.sh services/api minor
#   ./scripts/version-bump.sh services/auth major
#
# Bump types:
#   major - Increment major version (X.0.0)
#   minor - Increment minor version (x.Y.0)
#   patch - Increment patch version (x.y.Z)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <service-path> <bump-type>"
    echo ""
    echo "Arguments:"
    echo "  service-path  Path to service (e.g., apps/dashboard, services/api)"
    echo "  bump-type     Type of version bump: major, minor, or patch"
    echo ""
    echo "Examples:"
    echo "  $0 apps/dashboard patch"
    echo "  $0 services/api minor"
    echo "  $0 services/auth major"
    exit 1
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Parse semver version
parse_version() {
    local version=$1
    # Remove leading 'v' if present
    version=${version#v}
    # Extract major.minor.patch
    IFS='.' read -r major minor patch <<< "$version"
    # Handle prerelease suffixes
    patch=${patch%%-*}
    echo "$major $minor $patch"
}

# Bump version based on type
bump_version() {
    local current=$1
    local bump_type=$2

    read -r major minor patch <<< "$(parse_version "$current")"

    case $bump_type in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac

    echo "${major}.${minor}.${patch}"
}

# Main logic
main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    local service_path=$1
    local bump_type=$2

    # Validate bump type
    if [[ ! "$bump_type" =~ ^(major|minor|patch)$ ]]; then
        log_error "Invalid bump type: $bump_type. Must be major, minor, or patch."
        exit 1
    fi

    # Find version file
    local version_file=""
    local current_version=""

    if [[ -f "${service_path}/VERSION" ]]; then
        version_file="${service_path}/VERSION"
        current_version=$(cat "$version_file" | tr -d '[:space:]')
    elif [[ -f "${service_path}/package.json" ]]; then
        version_file="${service_path}/package.json"
        current_version=$(jq -r '.version' "$version_file")
    else
        log_error "No VERSION file or package.json found in ${service_path}"
        exit 1
    fi

    log_info "Current version: $current_version"

    # Calculate new version
    local new_version
    new_version=$(bump_version "$current_version" "$bump_type")

    log_info "New version: $new_version"

    # Update version file
    if [[ "$version_file" == *"VERSION" ]]; then
        echo "$new_version" > "$version_file"
    elif [[ "$version_file" == *"package.json" ]]; then
        # Use jq to update package.json
        local tmp_file
        tmp_file=$(mktemp)
        jq ".version = \"$new_version\"" "$version_file" > "$tmp_file"
        mv "$tmp_file" "$version_file"
    fi

    log_info "Updated ${version_file}"

    # Output for CI/CD
    echo "::set-output name=old_version::$current_version"
    echo "::set-output name=new_version::$new_version"

    # Show diff
    echo ""
    log_info "Version bumped: $current_version → $new_version"

    # Suggest git commands
    echo ""
    log_info "Suggested git commands:"
    local service_name
    service_name=$(basename "$service_path")
    echo "  git add ${version_file}"
    echo "  git commit -m \"chore(${service_name}): bump version to ${new_version}\""
}

main "$@"
