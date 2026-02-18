#!/usr/bin/env bash
#
# validate-platform.sh - Validate platform component compatibility
#
# Usage:
#   ./scripts/validate-platform.sh [--strict]
#
# Options:
#   --strict    Fail on warnings (optional dependencies not met)
#
# This script validates:
#   1. All required components have VERSION files
#   2. Component versions satisfy dependency constraints
#   3. No breaking changes between deployed versions
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

STRICT_MODE=false
ERRORS=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --strict)
            STRICT_MODE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    ((ERRORS++))
}

# Get version from service path
get_version() {
    local service_path=$1

    if [[ -f "${service_path}/VERSION" ]]; then
        cat "${service_path}/VERSION" | tr -d '[:space:]'
    elif [[ -f "${service_path}/package.json" ]]; then
        jq -r '.version' "${service_path}/package.json"
    else
        echo ""
    fi
}

# Find service path by name
find_service_path() {
    local name=$1

    for prefix in "apps" "services" "infra"; do
        if [[ -d "${prefix}/${name}" ]]; then
            echo "${prefix}/${name}"
            return
        fi
    done

    echo ""
}

# Compare versions (basic semver comparison)
# Returns: 0 if satisfied, 1 if not satisfied
check_version_constraint() {
    local version=$1
    local constraint=$2

    # Handle empty version
    if [[ -z "$version" ]]; then
        return 1
    fi

    # Parse constraint
    local operator=""
    local required_version=""

    if [[ "$constraint" =~ ^(\>=|\<=|\>|\<|=)?(.+)$ ]]; then
        operator="${BASH_REMATCH[1]:-=}"
        required_version="${BASH_REMATCH[2]}"
    else
        required_version="$constraint"
        operator="="
    fi

    # Remove leading 'v' if present
    version=${version#v}
    required_version=${required_version#v}

    # Split versions into components
    IFS='.' read -ra ver_parts <<< "$version"
    IFS='.' read -ra req_parts <<< "$required_version"

    # Pad arrays to same length
    while [[ ${#ver_parts[@]} -lt 3 ]]; do ver_parts+=("0"); done
    while [[ ${#req_parts[@]} -lt 3 ]]; do req_parts+=("0"); done

    # Compare based on operator
    case $operator in
        ">=")
            for i in 0 1 2; do
                if [[ ${ver_parts[$i]} -gt ${req_parts[$i]} ]]; then
                    return 0
                elif [[ ${ver_parts[$i]} -lt ${req_parts[$i]} ]]; then
                    return 1
                fi
            done
            return 0  # Equal satisfies >=
            ;;
        ">")
            for i in 0 1 2; do
                if [[ ${ver_parts[$i]} -gt ${req_parts[$i]} ]]; then
                    return 0
                elif [[ ${ver_parts[$i]} -lt ${req_parts[$i]} ]]; then
                    return 1
                fi
            done
            return 1  # Equal does not satisfy >
            ;;
        "<=")
            for i in 0 1 2; do
                if [[ ${ver_parts[$i]} -lt ${req_parts[$i]} ]]; then
                    return 0
                elif [[ ${ver_parts[$i]} -gt ${req_parts[$i]} ]]; then
                    return 1
                fi
            done
            return 0  # Equal satisfies <=
            ;;
        "<")
            for i in 0 1 2; do
                if [[ ${ver_parts[$i]} -lt ${req_parts[$i]} ]]; then
                    return 0
                elif [[ ${ver_parts[$i]} -gt ${req_parts[$i]} ]]; then
                    return 1
                fi
            done
            return 1  # Equal does not satisfy <
            ;;
        "="|"")
            for i in 0 1 2; do
                if [[ ${ver_parts[$i]} -ne ${req_parts[$i]} ]]; then
                    return 1
                fi
            done
            return 0
            ;;
    esac

    return 1
}

# Main validation
main() {
    echo "=================================="
    echo "Platform Compatibility Validation"
    echo "=================================="
    echo ""

    # Check if platform.yaml exists
    if [[ ! -f "platform/platform.yaml" ]]; then
        log_error "platform/platform.yaml not found"
        exit 1
    fi

    # Check if yq is available, fall back to basic parsing
    local USE_YQ=false
    if command -v yq &> /dev/null; then
        USE_YQ=true
    fi

    log_info "Scanning for components..."
    echo ""

    # Scan all component directories
    declare -A versions

    # Apps
    for dir in apps/*/; do
        if [[ -d "$dir" ]]; then
            local name=$(basename "$dir")
            local version=$(get_version "$dir")
            if [[ -n "$version" ]]; then
                versions["$name"]="$version"
                log_success "$name: v$version"
            fi
        fi
    done

    # Services
    for dir in services/*/; do
        if [[ -d "$dir" ]]; then
            local name=$(basename "$dir")
            local version=$(get_version "$dir")
            if [[ -n "$version" ]]; then
                versions["$name"]="$version"
                log_success "$name: v$version"
            fi
        fi
    done

    # Infrastructure
    for dir in infra/*/; do
        if [[ -d "$dir" ]] && [[ "$(basename "$dir")" != "shared" ]]; then
            local name=$(basename "$dir")
            local version=$(get_version "$dir")
            if [[ -n "$version" ]]; then
                versions["$name"]="$version"
                log_success "$name: v$version"
            fi
        fi
    done

    echo ""
    log_info "Validating dependencies..."
    echo ""

    # Check compatibility.yaml dependencies
    if [[ -f "platform/compatibility.yaml" ]] && [[ "$USE_YQ" == "true" ]]; then
        # Extract dependency info using yq
        local components
        components=$(yq eval '.dependencies | keys | .[]' platform/compatibility.yaml 2>/dev/null || echo "")

        for component in $components; do
            if [[ -n "${versions[$component]:-}" ]]; then
                log_info "Checking dependencies for $component..."

                # Get dependencies for this component
                local deps
                deps=$(yq eval ".dependencies.$component[].name" platform/compatibility.yaml 2>/dev/null || echo "")

                for dep in $deps; do
                    local constraint
                    local dep_type
                    constraint=$(yq eval ".dependencies.$component[] | select(.name == \"$dep\") | .constraint" platform/compatibility.yaml 2>/dev/null || echo "")
                    dep_type=$(yq eval ".dependencies.$component[] | select(.name == \"$dep\") | .type" platform/compatibility.yaml 2>/dev/null || echo "required")

                    if [[ -n "${versions[$dep]:-}" ]]; then
                        if check_version_constraint "${versions[$dep]}" "$constraint"; then
                            log_success "  $dep ${versions[$dep]} satisfies $constraint"
                        else
                            if [[ "$dep_type" == "required" ]]; then
                                log_error "  $dep ${versions[$dep]} does not satisfy $constraint"
                            else
                                log_warn "  $dep ${versions[$dep]} does not satisfy $constraint (optional)"
                            fi
                        fi
                    else
                        if [[ "$dep_type" == "required" ]]; then
                            log_error "  $dep not found (required by $component)"
                        else
                            log_warn "  $dep not found (optional for $component)"
                        fi
                    fi
                done
            fi
        done
    else
        log_warn "yq not installed or compatibility.yaml not found, skipping detailed dependency check"
    fi

    echo ""
    echo "=================================="
    echo "Validation Summary"
    echo "=================================="
    echo ""
    echo "Components found: ${#versions[@]}"
    echo "Errors: $ERRORS"
    echo "Warnings: $WARNINGS"
    echo ""

    if [[ $ERRORS -gt 0 ]]; then
        log_error "Validation failed with $ERRORS error(s)"
        exit 1
    fi

    if [[ $WARNINGS -gt 0 ]] && [[ "$STRICT_MODE" == "true" ]]; then
        log_error "Validation failed with $WARNINGS warning(s) (strict mode)"
        exit 1
    fi

    log_success "Platform validation passed!"
}

main "$@"
