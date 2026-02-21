#!/usr/bin/env bash
#
# Setup script for cicd-scaffolding
# Run this after forking the repository to create the required branches
# for the CI/CD pipeline to function properly.
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Default values
REMOTE="origin"
BASE_BRANCH="main"
DRY_RUN=false
SKIP_PUSH=false
SETUP_ENVIRONMENTS=false

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Setup script for cicd-scaffolding. Creates the required branches
(develop, staging) for the CI/CD pipeline after forking the repository.

Options:
    -r, --remote NAME       Remote name (default: origin)
    -b, --base BRANCH       Base branch to create from (default: main)
    -n, --dry-run           Show what would be done without making changes
    -l, --local-only        Create branches locally without pushing
    -e, --setup-envs        Setup GitHub environments (requires gh CLI)
    -h, --help              Show this help message

Examples:
    $(basename "$0")                    # Create and push branches
    $(basename "$0") --dry-run          # Preview changes
    $(basename "$0") --local-only       # Create branches without pushing
    $(basename "$0") --setup-envs       # Also configure GitHub environments

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--remote)
            REMOTE="$2"
            shift 2
            ;;
        -b|--base)
            BASE_BRANCH="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -l|--local-only)
            SKIP_PUSH=true
            shift
            ;;
        -e|--setup-envs)
            SETUP_ENVIRONMENTS=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    error "Not inside a git repository"
    exit 1
fi

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

info "Setting up cicd-scaffolding repository..."
echo ""

# Check if remote exists
if ! git remote get-url "$REMOTE" &>/dev/null; then
    error "Remote '$REMOTE' does not exist"
    echo "Available remotes:"
    git remote -v
    exit 1
fi

REMOTE_URL=$(git remote get-url "$REMOTE")
info "Using remote: $REMOTE ($REMOTE_URL)"

# Fetch latest from remote
if [[ "$DRY_RUN" == "false" ]]; then
    info "Fetching latest from $REMOTE..."
    git fetch "$REMOTE" --prune
fi

# Check base branch exists
if ! git show-ref --verify --quiet "refs/heads/$BASE_BRANCH" && \
   ! git show-ref --verify --quiet "refs/remotes/$REMOTE/$BASE_BRANCH"; then
    error "Base branch '$BASE_BRANCH' does not exist locally or on remote"
    exit 1
fi

# Ensure we're on the base branch and up to date
if [[ "$DRY_RUN" == "false" ]]; then
    info "Checking out $BASE_BRANCH..."
    git checkout "$BASE_BRANCH"

    if git show-ref --verify --quiet "refs/remotes/$REMOTE/$BASE_BRANCH"; then
        git pull "$REMOTE" "$BASE_BRANCH" --ff-only || true
    fi
fi

echo ""
info "Creating pipeline branches..."
echo ""

# Branches to create
BRANCHES=("develop" "staging")

for branch in "${BRANCHES[@]}"; do
    echo -n "  $branch: "

    # Check if branch exists locally
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        echo -e "${YELLOW}already exists locally${NC}"
        continue
    fi

    # Check if branch exists on remote
    if git show-ref --verify --quiet "refs/remotes/$REMOTE/$branch"; then
        echo -e "${YELLOW}exists on remote, checking out...${NC}"
        if [[ "$DRY_RUN" == "false" ]]; then
            git checkout -b "$branch" "$REMOTE/$branch"
            git checkout "$BASE_BRANCH"
        fi
        continue
    fi

    # Create the branch
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${BLUE}would create from $BASE_BRANCH${NC}"
    else
        git branch "$branch" "$BASE_BRANCH"
        echo -e "${GREEN}created from $BASE_BRANCH${NC}"
    fi
done

# Push branches to remote
if [[ "$SKIP_PUSH" == "false" ]]; then
    echo ""
    info "Pushing branches to $REMOTE..."
    echo ""

    for branch in "${BRANCHES[@]}"; do
        echo -n "  $branch: "

        # Check if already exists on remote
        if git show-ref --verify --quiet "refs/remotes/$REMOTE/$branch"; then
            echo -e "${YELLOW}already exists on remote${NC}"
            continue
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${BLUE}would push${NC}"
        else
            if git push -u "$REMOTE" "$branch"; then
                echo -e "${GREEN}pushed${NC}"
            else
                echo -e "${RED}failed to push${NC}"
            fi
        fi
    done
fi

# Setup GitHub environments
if [[ "$SETUP_ENVIRONMENTS" == "true" ]]; then
    echo ""
    info "Setting up GitHub environments..."

    if ! command -v gh &>/dev/null; then
        warn "GitHub CLI (gh) not found. Please install it to setup environments."
        warn "See: https://cli.github.com/"
    else
        # Check if authenticated
        if ! gh auth status &>/dev/null; then
            warn "Not authenticated with GitHub CLI. Run 'gh auth login' first."
        else
            ENVIRONMENTS=("development" "staging" "production")

            for env in "${ENVIRONMENTS[@]}"; do
                echo -n "  $env: "

                if [[ "$DRY_RUN" == "true" ]]; then
                    echo -e "${BLUE}would create${NC}"
                else
                    # Create environment (gh doesn't have a direct create command,
                    # but we can use the API)
                    REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

                    if gh api "repos/$REPO/environments/$env" &>/dev/null; then
                        echo -e "${YELLOW}already exists${NC}"
                    else
                        if gh api "repos/$REPO/environments/$env" -X PUT &>/dev/null; then
                            echo -e "${GREEN}created${NC}"
                        else
                            echo -e "${RED}failed to create${NC}"
                        fi
                    fi
                fi
            done

            echo ""
            warn "Note: Protection rules for 'production' environment must be configured manually."
            info "Go to: Settings > Environments > production > Add protection rule"
        fi
    fi
fi

echo ""
success "Setup complete!"
echo ""

# Summary
echo -e "${BLUE}Branch structure:${NC}

  main (production)
    └── staging (release candidates)
          └── develop (development)

${BLUE}Workflow:${NC}

  1. Create feature branches from 'develop'
  2. Open PR to 'develop' → builds beta versions, auto-deploys to dev
  3. Merge develop to 'staging' → builds RC versions, auto-deploys to staging
  4. Merge staging to 'main' → builds production versions, requires approval

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BLUE}Next steps:${NC}

  ${GREEN}1. Create GitHub Environments${NC}
     Go to: ${YELLOW}GitHub repo → Settings → Environments${NC}
     Create three environments:
       • development  (auto-deploys, no approval needed)
       • staging      (auto-deploys, no approval needed)
       • production   (add yourself as required reviewer)

  ${GREEN}2. Add Secrets${NC}
     Go to: ${YELLOW}GitHub repo → Settings → Environments → (select environment)${NC}
     Scroll to \"Environment secrets\" and add secrets based on your deployment type:

     ${BLUE}For Kubernetes:${NC}
       DEV_KUBECONFIG, STAGING_KUBECONFIG, PROD_KUBECONFIG
       (base64-encoded kubeconfig files)

     ${BLUE}For SSH/Server deployments:${NC}
       DEV_SSH_PRIVATE_KEY, DEV_SSH_USER
       STAGING_SSH_PRIVATE_KEY, STAGING_SSH_USER
       PROD_SSH_PRIVATE_KEY, PROD_SSH_USER

     ${BLUE}For database migrations:${NC}
       DEV_DATABASE_URL, DEV_DATABASE_USER, DEV_DATABASE_PASSWORD
       (repeat for STAGING_ and PROD_)

  ${GREEN}3. Start developing${NC}
     git checkout develop
     git checkout -b feature/my-service/add-feature

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${BLUE}For detailed instructions with examples, see:${NC}
  ${GREEN}SETUP_GUIDE.md${NC}
"
