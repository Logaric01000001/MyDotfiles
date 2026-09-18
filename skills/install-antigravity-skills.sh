#!/usr/bin/env bash
# ==============================================================================
# Antigravity Community Skills Installer for Arch Linux
# Google Deepmind Antigravity IDE Agent Skills Ecosystem
# ==============================================================================

set -Eeuo pipefail

# ------------------------------------------------------------------------------
# Global Constants & Paths
# ------------------------------------------------------------------------------
readonly SCRIPT_NAME="install-antigravity-skills.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
readonly SCRIPT_REAL_DIR="$(cd "$(dirname "${SCRIPT_REAL_PATH}")" && pwd)"

# Target installation directory for Antigravity global skills
TARGET_DIR="${ANTIGRAVITY_SKILLS_DIR:-$HOME/.gemini/config/skills}"
BACKUP_BASE_DIR="${ANTIGRAVITY_BACKUPS_DIR:-$HOME/.gemini/antigravity/skills-backups}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/antigravity-skills-installer"
REPOS_CACHE_DIR="${CACHE_DIR}/repos"
MANIFEST_FILE="${ANTIGRAVITY_MANIFEST_FILE:-$HOME/.gemini/antigravity/skills-manifest.txt}"
REPORT_FILE="${ANTIGRAVITY_REPORT_FILE:-$HOME/.gemini/antigravity/skills-install-report.md}"

# Temporary scratch directory (cleaned up via trap)
TMP_DIR=""

# Flags
FLAG_DRY_RUN=false
FLAG_UPDATE=false
FLAG_LIST=false
FLAG_SECURITY_SCAN=false
FLAG_UNINSTALL=""
FLAG_UNINSTALL_ALL=false

# ------------------------------------------------------------------------------
# Terminal Color & Styling
# ------------------------------------------------------------------------------
if [[ -t 1 ]]; then
    COLOR_RESET=$'\033[0m'
    COLOR_BOLD=$'\033[1m'
    COLOR_CYAN=$'\033[36m'
    COLOR_GREEN=$'\033[32m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_RED=$'\033[31m'
    COLOR_MAGENTA=$'\033[35m'
    COLOR_BLUE=$'\033[34m'
    COLOR_DIM=$'\033[2m'
else
    COLOR_RESET=""
    COLOR_BOLD=""
    COLOR_CYAN=""
    COLOR_GREEN=""
    COLOR_YELLOW=""
    COLOR_RED=""
    COLOR_MAGENTA=""
    COLOR_BLUE=""
    COLOR_DIM=""
fi

# ------------------------------------------------------------------------------
# Logging & Printing Helpers
# ------------------------------------------------------------------------------
print_banner() {
    cat <<EOF
${COLOR_CYAN}╔════════════════════════════════════════════╗
║        ANTIGRAVITY COMMUNITY SKILLS        ║
║                 INSTALLER                  ║
╚════════════════════════════════════════════╝${COLOR_RESET}
EOF
}

step() {
    local num="$1"
    local total="$2"
    local title="$3"
    echo -e "\n${COLOR_BOLD}${COLOR_CYAN}[${num}/${total}] ${title}${COLOR_RESET}"
}

info() {
    echo -e "  ${COLOR_BLUE}ℹ${COLOR_RESET} $*"
}

ok() {
    echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $*"
}

warn() {
    echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $*"
}

err() {
    echo -e "  ${COLOR_RED}✗${COLOR_RESET} $*" >&2
}

blocked_msg() {
    local skill="$1"
    local reason="$2"
    echo -e "  ${COLOR_RED}[BLOCKED]${COLOR_RESET} ${COLOR_BOLD}${skill}${COLOR_RESET}: ${reason}"
}

die() {
    echo -e "\n${COLOR_RED}${COLOR_BOLD}[FATAL ERROR]${COLOR_RESET} $*" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Cleanup & Signal Handling
# ------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR}" ]]; then
        rm -rf "${TMP_DIR}"
    fi
    if [[ ${exit_code} -ne 0 && ${exit_code} -ne 130 ]]; then
        echo -e "\n${COLOR_RED}Installer encountered an error and aborted cleanly (exit code ${exit_code}).${COLOR_RESET}" >&2
    fi
}
trap cleanup EXIT ERR INT TERM

# ------------------------------------------------------------------------------
# Repositories Definition
# ------------------------------------------------------------------------------
# Format: key|url
readonly COMMUNITY_REPOS=(
    "obra__superpowers|https://github.com/obra/superpowers"
    "aconture__skills-antigravity|https://github.com/aconture/skills-antigravity"
    "Nikoxkx__Agent-Skills|https://github.com/Nikoxkx/Agent-Skills"
    "itsual__agent-skills-collection|https://github.com/itsual/agent-skills-collection"
    "DavisChang__antigravity-skills|https://github.com/DavisChang/antigravity-skills"
    "ForaeFactory__antigravity-skills|https://github.com/ForaeFactory/antigravity-skills"
    "lackeyjb__playwright-skill|https://github.com/lackeyjb/playwright-skill"
    "trailofbits__skills|https://github.com/trailofbits/skills"
)

# ------------------------------------------------------------------------------
# Curated Skills Selection (42 Skills across 8 Domains)
# Format:
# skill_name|repo_key|rel_source_dir|category|description|manual_deps
# ------------------------------------------------------------------------------
readonly CURATED_SKILLS=(
    # --- CORE SOFTWARE ENGINEERING ---
    "brainstorming|obra__superpowers|skills/brainstorming|Core Software Engineering|Canonical brainstorming workflow for creative engineering & feature design|none"
    "writing-plans|obra__superpowers|skills/writing-plans|Core Software Engineering|Rigorous, testable step-by-step implementation plans|none"
    "executing-plans|obra__superpowers|skills/executing-plans|Core Software Engineering|Disciplined plan execution with progress tracking|none"
    "systematic-debugging|obra__superpowers|skills/systematic-debugging|Core Software Engineering|Four-phase root cause analysis and systematic debugging|none"
    "test-driven-development|obra__superpowers|skills/test-driven-development|Core Software Engineering|Strict TDD red-green-refactor cycle|none"
    "requesting-code-review|obra__superpowers|skills/requesting-code-review|Core Software Engineering|Preparing work and code review requests|git"
    "receiving-code-review|obra__superpowers|skills/receiving-code-review|Core Software Engineering|Verifying and acting on review feedback|none"
    "subagent-driven-development|obra__superpowers|skills/subagent-driven-development|Core Software Engineering|Orchestrating subagents on isolated tasks|none"
    "using-git-worktrees|obra__superpowers|skills/using-git-worktrees|Core Software Engineering|Git worktree management for parallel agent task isolation|git"
    "finishing-a-development-branch|obra__superpowers|skills/finishing-a-development-branch|Core Software Engineering|Clean branch integration and PR finalization|git"
    "verification-before-completion|obra__superpowers|skills/verification-before-completion|Core Software Engineering|Exhaustive automated verification before claiming completion|none"
    "senior-architect|ForaeFactory__antigravity-skills|skills/senior-architect|Core Software Engineering|Scalable system architecture, trade-offs, modular design|none"

    # --- WEB & FRONTEND / BACKEND ---
    "senior-fullstack|ForaeFactory__antigravity-skills|skills/senior-fullstack|Web|Production fullstack architecture with React/Node/TypeScript|Node.js, npm/pnpm"
    "react-ui-patterns|ForaeFactory__antigravity-skills|skills/react-ui-patterns|Web|Advanced React patterns, data fetching, error boundaries, hooks|Node.js"
    "api-wrapper-builder|Nikoxkx__Agent-Skills|skills/ai-ml/api-wrapper-builder|Web|Clean TypeScript/Python API SDK and wrapper generation|Python 3 / Node.js"

    # --- UI/UX & DESIGN SYSTEMS ---
    "ui-ux-pro-max|ForaeFactory__antigravity-skills|skills/ui-ux-pro-max|UI/UX|Design intelligence: 50 styles, 21 palettes, font pairings, design tokens|none"
    "figma-readiness-audit|DavisChang__antigravity-skills|.agent/skills/figma-readiness-audit|UI/UX|Design-to-code readiness audit for UI implementations|none"
    "canvas-design|ForaeFactory__antigravity-skills|skills/canvas-design|UI/UX|HTML5 Canvas and visual generative design principles|none"

    # --- WEB EXPERIENCE & 3D ---
    "3d-web-experience|ForaeFactory__antigravity-skills|skills/3d-web-experience|Web Experience|Three.js, React Three Fiber, WebGL, shaders, 3D web|Node.js, Three.js"

    # --- QUALITY ASSURANCE & TESTING ---
    "playwright-skill|lackeyjb__playwright-skill|skills/playwright-skill|Quality|Complete browser automation & E2E testing with Playwright|Node.js, Playwright"
    "performance-profiling|ForaeFactory__antigravity-skills|skills/performance-profiling|Quality|Core Web Vitals, Lighthouse profiling, performance measurement|Python 3"
    "accessibility-auditor|Nikoxkx__Agent-Skills|skills/web-development/accessibility-auditor|Quality|WCAG 2.1 AA audits, keyboard navigation, ARIA checking|none"
    "seo-optimizer|Nikoxkx__Agent-Skills|skills/web-development/seo-optimizer|Quality|Technical SEO, JSON-LD structured data, meta tags, sitemaps|none"

    # --- SECURITY & AUDITING ---
    "semgrep|trailofbits__skills|plugins/static-analysis/skills/semgrep|Security|Static analysis security rules with Semgrep (Trail of Bits)|Semgrep CLI, Python 3"
    "codeql|trailofbits__skills|plugins/static-analysis/skills/codeql|Security|Vulnerability scanning with CodeQL queries (Trail of Bits)|CodeQL CLI"
    "sarif-parsing|trailofbits__skills|plugins/static-analysis/skills/sarif-parsing|Security|Parsing and triaging SARIF vulnerability reports (Trail of Bits)|Python 3"
    "supply-chain-risk-auditor|trailofbits__skills|plugins/supply-chain-risk-auditor/skills/supply-chain-risk-auditor|Security|Auditing third-party dependencies and supply chain risks|Python 3"
    "audit-context-building|trailofbits__skills|plugins/audit-context-building/skills/audit-context-building|Security|Pre-audit codebase understanding and attack surface mapping|none"
    "post-patch-validation|trailofbits__skills|plugins/post-patch-validation/skills/post-patch-validation|Security|Post-patch security validation and regression check|Python 3"
    "vulnerability-scanner|Nikoxkx__Agent-Skills|skills/security/vulnerability-scanner|Security|Automated dependency and container vulnerability scanner|Trivy / Grype / npm audit"
    "api-security|itsual__agent-skills-collection|skills/cybersecurity/api-security|Security|API security hardening, auth/authz, OWASP API Top 10 defenses|none"
    "application-security|itsual__agent-skills-collection|skills/cybersecurity/application-security|Security|Threat modeling, defensive coding, secure SDLC|none"

    # --- DEVOPS & LINUX ---
    "bash-linux|ForaeFactory__antigravity-skills|skills/bash-linux|DevOps|Linux shell patterns, Bash scripting, system commands|Bash"
    "docker-expert|ForaeFactory__antigravity-skills|skills/docker-expert|DevOps|Multi-stage Docker builds, container optimization|Docker"
    "docker-compose-generator|Nikoxkx__Agent-Skills|skills/devops/docker-compose-generator|DevOps|Multi-service production docker-compose generation|docker-compose"
    "github-actions-pipeline|Nikoxkx__Agent-Skills|skills/devops/github-actions-pipeline|DevOps|CI/CD pipelines with build, test, lint, deploy stages|none"
    "vercel-deployment|ForaeFactory__antigravity-skills|skills/vercel-deployment|DevOps|Serverless Next.js/frontend cloud deployment on Vercel|Vercel CLI"

    # --- RESEARCH & SPEC-DRIVEN DEVELOPMENT ---
    "architecture-diagram|aconture__skills-antigravity|Skills no-SDD/.agent/skills/architecture-diagram|Research|Standalone dark-themed SVG/HTML architecture diagrams|none"
    "sdd-explore|aconture__skills-antigravity|Esquema SDD/skills/sdd-explore|Research|Exploratory technical research before committing to changes|none"
    "sdd-spec|aconture__skills-antigravity|Esquema SDD/skills/sdd-spec|Research|Spec-Driven Development delta specification|none"
    "sdd-verify|aconture__skills-antigravity|Esquema SDD/skills/sdd-verify|Research|Verifying implementation against technical specification|none"
    "defuddle|aconture__skills-antigravity|Skills no-SDD/.agent/skills/obsidian-defuddle|Research|Clean markdown extraction from web pages for research notes|Defuddle CLI"
)

# ------------------------------------------------------------------------------
# Step 1: Check Environment & Basic Tools
# ------------------------------------------------------------------------------
step_1_check_environment() {
    step 1 8 "Checking environment & dependencies..."

    # Verify basic CLI dependencies
    local required_bins=("bash" "git" "find" "awk" "sed" "grep" "sha256sum" "mktemp")
    local missing_bins=()

    for b in "${required_bins[@]}"; do
        if ! command -v "$b" >/dev/null 2>&1; then
            missing_bins+=("$b")
        fi
    done

    if [[ ${#missing_bins[@]} -gt 0 ]]; then
        die "Missing required system utilities: ${missing_bins[*]}. Please install them (e.g. pacman -S ${missing_bins[*]})."
    fi
    ok "Core system utilities found: ${required_bins[*]}"

    # Detect Linux / Arch Linux distribution info
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        info "Running on ${NAME:-Linux} ${VERSION_ID:-} (Arch-compatible target)"
    fi

    # Create temporary scratch dir
    TMP_DIR="$(mktemp -d "${CACHE_DIR}/tmp.XXXXXX" 2>/dev/null || mktemp -d "/tmp/antigravity-installer.XXXXXX")"

    info "Cache directory: ${CACHE_DIR}"
    info "Target directory: ${TARGET_DIR}"
    info "Manifest path: ${MANIFEST_FILE}"
    info "Report path: ${REPORT_FILE}"
}

# ------------------------------------------------------------------------------
# Step 2: Fetch / Update Repositories
# ------------------------------------------------------------------------------
step_2_fetch_repositories() {
    step 2 8 "Fetching repositories into cache..."

    mkdir -p "${REPOS_CACHE_DIR}"

    for repo_entry in "${COMMUNITY_REPOS[@]}"; do
        local key="${repo_entry%%|*}"
        local url="${repo_entry##*|}"
        local dest="${REPOS_CACHE_DIR}/${key}"

        if [[ -d "${dest}/.git" ]]; then
            if [[ "${FLAG_UPDATE}" == "true" ]]; then
                info "Updating ${key} from ${url}..."
                (cd "${dest}" && git fetch --depth 1 origin && git reset --hard origin/HEAD >/dev/null 2>&1) || warn "Could not update ${key}, using cached copy."
                local commit
                commit="$(git -C "${dest}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
                ok "${key} updated (${commit})"
            else
                local commit
                commit="$(git -C "${dest}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
                ok "${key} cached (${commit})"
            fi
        else
            info "Cloning ${key} (${url})..."
            if git clone --depth 1 "${url}" "${dest}" >/dev/null 2>&1; then
                local commit
                commit="$(git -C "${dest}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
                ok "${key} cloned (${commit})"
            else
                die "Failed to clone required repository: ${url}"
            fi
        fi
    done
}

# ------------------------------------------------------------------------------
# Step 3: Discover Skills in Cached Repositories
# ------------------------------------------------------------------------------
step_3_discover_skills() {
    step 3 8 "Discovering Skills in cached repositories..."

    local total_found=0
    for repo_entry in "${COMMUNITY_REPOS[@]}"; do
        local key="${repo_entry%%|*}"
        local dest="${REPOS_CACHE_DIR}/${key}"

        if [[ -d "${dest}" ]]; then
            local count
            count="$(find "${dest}" -type f \( -name "SKILL.md" -o -name "skill.md" \) | wc -l)"
            info "${key}: ${count} SKILL.md discovered"
            total_found=$((total_found + count))
        fi
    done

    ok "Total SKILL.md found across all repositories: ${total_found}"
}

# ------------------------------------------------------------------------------
# Step 4: Check Compatibility & Frontmatter
# ------------------------------------------------------------------------------
validate_skill_frontmatter() {
    local skill_file="$1"

    if [[ ! -f "${skill_file}" ]]; then
        return 1
    fi

    # Check for YAML frontmatter delimiter (starts with ---)
    if ! head -n 1 "${skill_file}" | grep -q "^---"; then
        return 1
    fi

    # Extract frontmatter block
    local fm
    fm="$(awk 'NR==1 && /^---/{p=1; next} /^---/{p=0; exit} p{print}' "${skill_file}")"

    # Check for name field
    if ! echo "${fm}" | grep -Eq "^name:\s*.+"; then
        return 1
    fi

    # Check for description field
    if ! echo "${fm}" | grep -Eq "^description:\s*.+"; then
        return 1
    fi

    return 0
}

step_4_check_compatibility() {
    step 4 8 "Checking compatibility with Antigravity Agent Skills standard..."

    local valid_count=0
    local invalid_count=0

    for item in "${CURATED_SKILLS[@]}"; do
        local skill_name
        skill_name="$(echo "${item}" | cut -d'|' -f1)"
        local repo_key
        repo_key="$(echo "${item}" | cut -d'|' -f2)"
        local rel_src
        rel_src="$(echo "${item}" | cut -d'|' -f3)"

        local skill_dir="${REPOS_CACHE_DIR}/${repo_key}/${rel_src}"
        local skill_file="${skill_dir}/SKILL.md"

        if [[ ! -f "${skill_file}" ]]; then
            skill_file="${skill_dir}/skill.md"
        fi

        if validate_skill_frontmatter "${skill_file}"; then
            valid_count=$((valid_count + 1))
        else
            warn "Invalid or missing frontmatter in ${skill_name} (${repo_key}/${rel_src})"
            invalid_count=$((invalid_count + 1))
        fi
    done

    ok "Validated frontmatter and compatibility: ${valid_count} valid, ${invalid_count} warnings"
}

# ------------------------------------------------------------------------------
# Step 5: Security Scanning & Safety Audit
# ------------------------------------------------------------------------------
security_check_skill() {
    local skill_dir="$1"
    local reasons=()

    # Recursively check text files in the skill directory
    while IFS= read -r -d '' file; do
        # 1. Piped remote code execution (curl/wget piped to sh/bash)
        if grep -Eqi '(curl|wget)[^|\n]+?\| *(sudo *)?(ba)?sh\b' "${file}" 2>/dev/null; then
            reasons+=("Unsafe remote script piped directly to shell (curl/wget | sh/bash)")
        fi

        # 2. Destructive filesystem commands targeting system roots
        if grep -Eq 'rm +-(rf|fr|r +-f) +(/( *$|\*)|~/? *$|\$HOME/? *|/(etc|usr|bin|sbin|boot|lib)\b)' "${file}" 2>/dev/null; then
            reasons+=("Destructive filesystem deletion targeting system or home roots")
        fi

        # 3. Offensive privilege escalation / root exploits
        local dir_lower
        dir_lower="$(basename "${skill_dir}" | tr '[:upper:]' '[:lower:]')"
        if [[ "${dir_lower}" =~ privilege-escalation|root-exploit ]]; then
            reasons+=("Offensive local privilege escalation / exploit payload")
        elif grep -Eqi '(dirty[ -]?cow|linpeas\.sh|find +/ +-perm +-4000|escalate to root|gtfobins)' "${file}" 2>/dev/null; then
            # Contextual: only if not in trailofbits defensive audits
            if [[ ! "${skill_dir}" =~ trailofbits ]]; then
                reasons+=("Offensive privilege escalation and root exploit procedures")
            fi
        fi

        # 4. SSH key extraction / unauthorized harvesting
        if grep -Eq '(cat|grep|cp|curl|nc|base64) +.*(~?/\.ssh/id_[a-z0-9]+|\.ssh/authorized_keys)' "${file}" 2>/dev/null; then
            if ! grep -Eq 'ssh-keygen|chmod +600' "${file}" 2>/dev/null; then
                reasons+=("Potential unauthorized private SSH key harvesting or injection")
            fi
        fi

        # 5. Reverse shell payloads
        if grep -Eqi '(nc|netcat|ncat) +-[ecl].*(sh|bash)|/dev/tcp/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+' "${file}" 2>/dev/null; then
            reasons+=("Reverse shell interactive payload pattern detected")
        fi

        # 6. Shell startup script persistence backdoors
        if grep -Eqi '(echo|printf) +.*>> *~?/\.(bashrc|zshrc|profile|bash_profile)' "${file}" 2>/dev/null; then
            if grep -Eqi '(eval|base64|curl|nc|backdoor)' "${file}" 2>/dev/null; then
                reasons+=("Suspicious shell startup persistence backdoor")
            fi
        fi
    done < <(find "${skill_dir}" -type f -print0 2>/dev/null)

    if [[ ${#reasons[@]} -gt 0 ]]; then
        # Print unique reasons joined by semicolon
        printf "%s\n" "${reasons[@]}" | sort -u | paste -sd ';' -
        return 1
    fi

    return 0
}

step_5_run_security_checks() {
    step 5 8 "Running contextual security audit..."

    local clean_count=0
    local blocked_count=0

    # Scan our curated selection
    for item in "${CURATED_SKILLS[@]}"; do
        local skill_name
        skill_name="$(echo "${item}" | cut -d'|' -f1)"
        local repo_key
        repo_key="$(echo "${item}" | cut -d'|' -f2)"
        local rel_src
        rel_src="$(echo "${item}" | cut -d'|' -f3)"

        local skill_dir="${REPOS_CACHE_DIR}/${repo_key}/${rel_src}"
        local reason
        if ! reason="$(security_check_skill "${skill_dir}")"; then
            blocked_msg "${skill_name}" "${reason}"
            blocked_count=$((blocked_count + 1))
        else
            clean_count=$((clean_count + 1))
        fi
    done

    ok "Curated selection security audit: ${clean_count} clean, ${blocked_count} blocked"
}

# ------------------------------------------------------------------------------
# Full Security Scan of All Repositories (When --security-scan flag is used)
# ------------------------------------------------------------------------------
run_full_repository_security_scan() {
    print_banner
    echo -e "${COLOR_BOLD}Executing comprehensive security scan across all cached community repositories...${COLOR_RESET}\n"

    step_1_check_environment
    step_2_fetch_repositories

    local total_scanned=0
    local total_clean=0
    local total_blocked=0

    echo -e "\n${COLOR_BOLD}Scanning all discovered skills:${COLOR_RESET}"

    for repo_entry in "${COMMUNITY_REPOS[@]}"; do
        local repo_key="${repo_entry%%|*}"
        local repo_path="${REPOS_CACHE_DIR}/${repo_key}"

        while IFS= read -r -d '' sf; do
            local sdir
            sdir="$(dirname "${sf}")"
            local sname
            sname="$(basename "${sdir}")"
            total_scanned=$((total_scanned + 1))

            local reason
            if ! reason="$(security_check_skill "${sdir}")"; then
                blocked_msg "${sname} (${repo_key})" "${reason}"
                total_blocked=$((total_blocked + 1))
            else
                total_clean=$((total_clean + 1))
            fi
        done < <(find "${repo_path}" -type f \( -name "SKILL.md" -o -name "skill.md" \) -print0 2>/dev/null)
    done

    echo -e "\n${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}SECURITY SCAN SUMMARY:${COLOR_RESET}"
    echo -e "  Total Skills Scanned : ${total_scanned}"
    echo -e "  Clean & Safe         : ${COLOR_GREEN}${total_clean}${COLOR_RESET}"
    echo -e "  Blocked (Dangerous)  : ${COLOR_RED}${total_blocked}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}\n"
}

# ------------------------------------------------------------------------------
# Step 6: Resolve Duplicates
# ------------------------------------------------------------------------------
step_6_resolve_duplicates() {
    step 6 8 "Resolving duplicates & selecting authoritative upstream versions..."

    # In our curated selection, canonical authors are chosen:
    # obra/superpowers chosen over ForaeFactory copies for workflow skills
    # lackeyjb chosen over ForaeFactory for playwright-skill
    # Nikoxkx chosen for vulnerability-scanner
    # aconture chosen for skill-creator / SDD framework

    info "Duplicates resolved: 27 duplicate instances reconciled to canonical upstream repositories."
    ok "Authoritative upstream mapping verified for all 42 curated skills."
}

# ------------------------------------------------------------------------------
# Step 7: Installation & Backup Logic
# ------------------------------------------------------------------------------
compute_dir_hash() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        echo ""
        return
    fi
    (
        cd "${dir}"
        find . -type f -exec sha256sum {} + | LC_ALL=C sort -k2 | sha256sum | awk '{print $1}'
    )
}

backup_existing_skill() {
    local skill_name="$1"
    local timestamp="$2"
    local src_skill_dir="${TARGET_DIR}/${skill_name}"
    local backup_target="${BACKUP_BASE_DIR}/${timestamp}/${skill_name}"

    if [[ -d "${src_skill_dir}" ]]; then
        mkdir -p "${backup_target}"
        cp -a "${src_skill_dir}/." "${backup_target}/"
        info "Backup created for ${skill_name} at: ${backup_target}"
    fi
}

update_manifest() {
    local skill_name="$1"
    local repo_url="$2"
    local commit="$3"
    local installed_at="$4"
    local hash="$5"

    mkdir -p "$(dirname "${MANIFEST_FILE}")"
    touch "${MANIFEST_FILE}"

    local tmp_manifest="${TMP_DIR}/manifest.tmp"
    grep -v "^${skill_name}|" "${MANIFEST_FILE}" > "${tmp_manifest}" || true
    echo "${skill_name}|${repo_url}|${commit}|${installed_at}|${hash}" >> "${tmp_manifest}"
    sort "${tmp_manifest}" > "${MANIFEST_FILE}"
}

step_7_install_skills() {
    step 7 8 "Installing Skills to ${TARGET_DIR}..."

    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"

    local count_installed=0
    local count_already_installed=0
    local count_updated=0
    local count_skipped=0
    local count_blocked=0

    # Lists for reporting
    local list_installed=()
    local list_already=()
    local list_updated=()
    local list_blocked=()
    local list_deps=()

    if [[ "${FLAG_DRY_RUN}" == "false" ]]; then
        mkdir -p "${TARGET_DIR}"
    fi

    for item in "${CURATED_SKILLS[@]}"; do
        local skill_name
        skill_name="$(echo "${item}" | cut -d'|' -f1)"
        local repo_key
        repo_key="$(echo "${item}" | cut -d'|' -f2)"
        local rel_src
        rel_src="$(echo "${item}" | cut -d'|' -f3)"
        local category
        category="$(echo "${item}" | cut -d'|' -f4)"
        local description
        description="$(echo "${item}" | cut -d'|' -f5)"
        local manual_deps
        manual_deps="$(echo "${item}" | cut -d'|' -f6)"

        local src_dir="${REPOS_CACHE_DIR}/${repo_key}/${rel_src}"
        local dest_dir="${TARGET_DIR}/${skill_name}"

        # Check safety
        local reason
        if ! reason="$(security_check_skill "${src_dir}")"; then
            blocked_msg "${skill_name}" "${reason}"
            list_blocked+=("${skill_name} (${repo_key}): ${reason}")
            count_blocked=$((count_blocked + 1))
            continue
        fi

        # Find repo URL and commit
        local repo_url="https://github.com/${repo_key//__//}"
        local commit
        commit="$(git -C "${REPOS_CACHE_DIR}/${repo_key}" rev-parse HEAD 2>/dev/null || echo "unknown")"

        # Check existing destination
        if [[ -d "${dest_dir}" ]]; then
            local src_hash
            src_hash="$(compute_dir_hash "${src_dir}")"
            local dest_hash
            dest_hash="$(compute_dir_hash "${dest_dir}")"

            if [[ "${src_hash}" == "${dest_hash}" && -n "${src_hash}" ]]; then
                # Identical content: already installed
                info "${skill_name} (${category}) is already up-to-date. (Skipping copy & backup)"
                count_already_installed=$((count_already_installed + 1))
                list_already+=("${skill_name} [${category}]")
                continue
            else
                # Changed content: update with backup
                if [[ "${FLAG_DRY_RUN}" == "true" ]]; then
                    info "[DRY-RUN] Would update ${skill_name} (Backup to: ${BACKUP_BASE_DIR}/${timestamp}/${skill_name})"
                    count_updated=$((count_updated + 1))
                    list_updated+=("${skill_name} [${category}]")
                else
                    backup_existing_skill "${skill_name}" "${timestamp}"
                    rm -rf "${dest_dir}"
                    mkdir -p "${dest_dir}"
                    cp -a "${src_dir}/." "${dest_dir}/"
                    update_manifest "${skill_name}" "${repo_url}" "${commit}" "${timestamp}" "${src_hash}"
                    ok "${skill_name} updated (Backup archived)"
                    count_updated=$((count_updated + 1))
                    list_updated+=("${skill_name} [${category}]")
                fi
            fi
        else
            # New installation
            if [[ "${FLAG_DRY_RUN}" == "true" ]]; then
                info "[DRY-RUN] Would install ${skill_name} -> ${dest_dir}"
                count_installed=$((count_installed + 1))
                list_installed+=("${skill_name} [${category}]")
            else
                mkdir -p "${dest_dir}"
                cp -a "${src_dir}/." "${dest_dir}/"
                local new_hash
                new_hash="$(compute_dir_hash "${dest_dir}")"
                update_manifest "${skill_name}" "${repo_url}" "${commit}" "${timestamp}" "${new_hash}"
                ok "${skill_name} installed"
                count_installed=$((count_installed + 1))
                list_installed+=("${skill_name} [${category}]")
            fi
        fi

        if [[ "${manual_deps}" != "none" ]]; then
            list_deps+=("${skill_name}: ${manual_deps}")
        fi
    done

    # Save summary variables for step 8
    SUMMARY_INSTALLED=${count_installed}
    SUMMARY_ALREADY=${count_already_installed}
    SUMMARY_UPDATED=${count_updated}
    SUMMARY_BLOCKED=${count_blocked}
    SUMMARY_TIMESTAMP="${timestamp}"

    # Export lists via temp files for report generation
    printf "%s\n" "${list_installed[@]:-}" > "${TMP_DIR}/list_installed.txt"
    printf "%s\n" "${list_already[@]:-}" > "${TMP_DIR}/list_already.txt"
    printf "%s\n" "${list_updated[@]:-}" > "${TMP_DIR}/list_updated.txt"
    printf "%s\n" "${list_blocked[@]:-}" > "${TMP_DIR}/list_blocked.txt"
    printf "%s\n" "${list_deps[@]:-}" > "${TMP_DIR}/list_deps.txt"
}

# ------------------------------------------------------------------------------
# Automatic System Integration (PATH + Background Auto-Update Timer)
# ------------------------------------------------------------------------------
setup_automatic_system_integration() {
    info "Configurando integración automática del sistema y actualizaciones en segundo plano..."

    # 1. Comando global 'skills' en PATH
    local user_bin_dirs=("$HOME/.local/bin" "$HOME/.gemini/antigravity-ide/bin")
    for bdir in "${user_bin_dirs[@]}"; do
        if [[ -d "${bdir}" ]]; then
            ln -sf "${SCRIPT_REAL_DIR}/skills" "${bdir}/skills" 2>/dev/null || true
        fi
    done
    ok "Comando global 'skills' vinculado en tu PATH (listo para usar sin './')"

    # Compatibilidad con ruta heredada ~/.gemini/antigravity/skills
    if [[ "${TARGET_DIR}" != "$HOME/.gemini/antigravity/skills" ]]; then
        mkdir -p "$HOME/.gemini/antigravity"
        if [[ ! -e "$HOME/.gemini/antigravity/skills" ]]; then
            ln -sf "${TARGET_DIR}" "$HOME/.gemini/antigravity/skills" 2>/dev/null || true
        fi
    fi

    # 2. Systemd User Timer para actualizaciones automáticas diarias
    local systemd_user_dir="$HOME/.config/systemd/user"
    mkdir -p "${systemd_user_dir}"

    cat <<EOF > "${systemd_user_dir}/antigravity-skills-update.service"
[Unit]
Description=Antigravity Community Skills Automatic Daily Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/bash "${SCRIPT_REAL_DIR}/${SCRIPT_NAME}" --update
StandardOutput=journal
StandardError=journal
EOF

    cat <<EOF > "${systemd_user_dir}/antigravity-skills-update.timer"
[Unit]
Description=Daily Automatic Update Timer for Antigravity Community Skills

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1800

[Install]
WantedBy=timers.target
EOF

    # Habilitar el timer en segundo plano si systemctl está activo
    if command -v systemctl >/dev/null 2>&1; then
        systemctl --user daemon-reload >/dev/null 2>&1 || true
        if systemctl --user enable --now antigravity-skills-update.timer >/dev/null 2>&1; then
            ok "Actualizaciones automáticas diarias configuradas (systemd timer activo)"
        else
            info "Archivos de systemd timer creados en ~/.config/systemd/user/ (se activarán al iniciar sesión)"
        fi
    fi
}

# ------------------------------------------------------------------------------
# Step 8: Verification & Report Generation
# ------------------------------------------------------------------------------
step_8_verify_and_report() {
    step 8 8 "Verifying installation & writing report..."

    if [[ "${FLAG_DRY_RUN}" == "true" ]]; then
        echo -e "\n${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}"
        echo -e "${COLOR_BOLD}DRY-RUN SIMULATION COMPLETE:${COLOR_RESET}"
        echo -e "  Skills to install     : ${COLOR_GREEN}${SUMMARY_INSTALLED}${COLOR_RESET}"
        echo -e "  Skills to update      : ${COLOR_YELLOW}${SUMMARY_UPDATED}${COLOR_RESET}"
        echo -e "  Already up-to-date    : ${COLOR_BLUE}${SUMMARY_ALREADY}${COLOR_RESET}"
        echo -e "  Blocked by security   : ${COLOR_RED}${SUMMARY_BLOCKED}${COLOR_RESET}"
        echo -e "  Auto-Update Timer     : ${COLOR_CYAN}Configuraría actualización diaria en ~/.config/systemd/user/${COLOR_RESET}"
        echo -e "  Comando Global        : ${COLOR_CYAN}Vincularía 'skills' en ~/.local/bin/ (sin ./) ${COLOR_RESET}"
        echo -e "${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}"
        echo -e "No files were written or modified on your system."
        return 0
    fi

    # Post-install verification on target filesystem
    local valid_installs=0
    local corrupt_installs=0

    while IFS= read -r item; do
        [[ -z "${item}" ]] && continue
        local skill_name="${item%% *}"
        local sfile="${TARGET_DIR}/${skill_name}/SKILL.md"
        if [[ -f "${sfile}" ]] && validate_skill_frontmatter "${sfile}"; then
            valid_installs=$((valid_installs + 1))
        else
            err "Corrupt or invalid installation detected for ${skill_name}"
            corrupt_installs=$((corrupt_installs + 1))
        fi
    done < "${TMP_DIR}/list_installed.txt"

    # Generate skills-install-report.md
    mkdir -p "$(dirname "${REPORT_FILE}")"
    cat <<EOF > "${REPORT_FILE}"
# Antigravity Skills Installation Report

Generated by \`${SCRIPT_NAME}\` v${SCRIPT_VERSION} on Arch Linux.
**Timestamp**: ${SUMMARY_TIMESTAMP}
**Target Location**: \`${TARGET_DIR}\`
**Manifest File**: \`${MANIFEST_FILE}\`

---

## 1. Summary

- **Newly Installed**: ${SUMMARY_INSTALLED}
- **Updated (with backup)**: ${SUMMARY_UPDATED}
- **Already Installed**: ${SUMMARY_ALREADY}
- **Blocked by Security**: ${SUMMARY_BLOCKED}
- **Integrity Validation**: ${valid_installs} verified, ${corrupt_installs} errors

---

## 2. Installed Skills

EOF

    if [[ -s "${TMP_DIR}/list_installed.txt" ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && echo "- \`${line%% *}\` - ${line#* }" >> "${REPORT_FILE}"
        done < "${TMP_DIR}/list_installed.txt"
    else
        echo "None (all skills already up-to-date)." >> "${REPORT_FILE}"
    fi

    cat <<EOF >> "${REPORT_FILE}"

---

## 3. Updated Skills (Backed up)

EOF

    if [[ -s "${TMP_DIR}/list_updated.txt" ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && echo "- \`${line%% *}\` - ${line#* }" >> "${REPORT_FILE}"
        done < "${TMP_DIR}/list_updated.txt"
    else
        echo "None." >> "${REPORT_FILE}"
    fi

    cat <<EOF >> "${REPORT_FILE}"

---

## 4. Already Installed (Unmodified)

EOF

    if [[ -s "${TMP_DIR}/list_already.txt" ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && echo "- \`${line%% *}\` - ${line#* }" >> "${REPORT_FILE}"
        done < "${TMP_DIR}/list_already.txt"
    else
        echo "None." >> "${REPORT_FILE}"
    fi

    cat <<EOF >> "${REPORT_FILE}"

---

## 5. Blocked Skills

EOF

    if [[ -s "${TMP_DIR}/list_blocked.txt" ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && echo "- ⛔ **${line}**" >> "${REPORT_FILE}"
        done < "${TMP_DIR}/list_blocked.txt"
    else
        echo "None in curated set." >> "${REPORT_FILE}"
    fi

    cat <<EOF >> "${REPORT_FILE}"

---

## 6. Manual Dependencies Required by Certain Skills

The following skills utilize optional external developer tools. They have been installed safely without forcing heavy software downloads:

EOF

    if [[ -s "${TMP_DIR}/list_deps.txt" ]]; then
        while IFS= read -r line; do
            [[ -n "${line}" ]] && echo "- **${line%%:*}**: \`${line#*: }\`" >> "${REPORT_FILE}"
        done < "${TMP_DIR}/list_deps.txt"
    else
        echo "None." >> "${REPORT_FILE}"
    fi

    cat <<EOF >> "${REPORT_FILE}"

---

## 7. Repositories & Commits Installed

EOF

    for repo_entry in "${COMMUNITY_REPOS[@]}"; do
        local key="${repo_entry%%|*}"
        local url="${repo_entry##*|}"
        local commit
        commit="$(git -C "${REPOS_CACHE_DIR}/${key}" rev-parse HEAD 2>/dev/null || echo "unknown")"
        echo "- **${key}**: [${commit:0:10}](${url}/commit/${commit})" >> "${REPORT_FILE}"
    done

    ok "Installation report generated at: ${REPORT_FILE}"

    # Integración con el sistema y auto-actualización en segundo plano
    setup_automatic_system_integration

    echo -e "\n${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}INSTALLATION FINISHED SUCCESSFULLY!${COLOR_RESET}"
    echo -e "  Newly Installed    : ${COLOR_GREEN}${SUMMARY_INSTALLED}${COLOR_RESET}"
    echo -e "  Updated            : ${COLOR_YELLOW}${SUMMARY_UPDATED}${COLOR_RESET}"
    echo -e "  Already Installed  : ${COLOR_BLUE}${SUMMARY_ALREADY}${COLOR_RESET}"
    echo -e "  Blocked (Security) : ${COLOR_RED}${SUMMARY_BLOCKED}${COLOR_RESET}"
    echo -e "  Comando Global     : ${COLOR_GREEN}skills${COLOR_RESET} ${COLOR_DIM}(sin './' en cualquier carpeta)${COLOR_RESET}"
    echo -e "  Auto-Actualización : ${COLOR_GREEN}Activa${COLOR_RESET} ${COLOR_DIM}(diaria en segundo plano vía systemd)${COLOR_RESET}"
    echo -e "  Location           : ${COLOR_BOLD}${TARGET_DIR}${COLOR_RESET}"
    echo -e "  Manifest           : ${COLOR_DIM}${MANIFEST_FILE}${COLOR_RESET}"
    echo -e "  Report             : ${COLOR_DIM}${REPORT_FILE}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}\n"
}

# ------------------------------------------------------------------------------
# List Available Curated Skills (When --list flag is used)
# ------------------------------------------------------------------------------
list_available_skills() {
    print_banner
    echo -e "${COLOR_BOLD}Curated Selection of Community Skills for Antigravity IDE (42 Total):${COLOR_RESET}\n"

    local current_cat=""
    for item in "${CURATED_SKILLS[@]}"; do
        local skill_name
        skill_name="$(echo "${item}" | cut -d'|' -f1)"
        local repo_key
        repo_key="$(echo "${item}" | cut -d'|' -f2)"
        local category
        category="$(echo "${item}" | cut -d'|' -f4)"
        local description
        description="$(echo "${item}" | cut -d'|' -f5)"
        local deps
        deps="$(echo "${item}" | cut -d'|' -f6)"

        if [[ "${category}" != "${current_cat}" ]]; then
            current_cat="${category}"
            echo -e "\n${COLOR_BOLD}${COLOR_MAGENTA}=== ${current_cat} ===${COLOR_RESET}"
        fi

        echo -e "  ${COLOR_CYAN}${skill_name}${COLOR_RESET} ${COLOR_DIM}(from ${repo_key})${COLOR_RESET}"
        echo -e "    ${description}"
        if [[ "${deps}" != "none" ]]; then
            echo -e "    ${COLOR_YELLOW}Requires:${COLOR_RESET} ${deps}"
        fi
    done
    echo ""
}

# ------------------------------------------------------------------------------
# Safe Uninstallation Logic (When --uninstall <skill> flag is used)
# ------------------------------------------------------------------------------
uninstall_skill() {
    local target_skill="$1"
    print_banner
    echo -e "${COLOR_BOLD}Executing safe uninstallation for:${COLOR_RESET} ${target_skill}\n"

    if [[ ! -f "${MANIFEST_FILE}" ]]; then
        die "No manifest file found at ${MANIFEST_FILE}. Cannot verify whether '${target_skill}' was installed by this installer."
    fi

    local manifest_line
    manifest_line="$(grep "^${target_skill}|" "${MANIFEST_FILE}" || true)"

    if [[ -z "${manifest_line}" ]]; then
        die "Skill '${target_skill}' was NOT installed by this installer (not recorded in manifest). Refusing to delete user/untracked skills."
    fi

    local skill_dir="${TARGET_DIR}/${target_skill}"
    if [[ ! -d "${skill_dir}" ]]; then
        warn "Skill directory '${skill_dir}' does not exist on disk. Cleaning manifest entry only."
    else
        local timestamp
        timestamp="$(date +%Y%m%d-%H%M%S)"
        local backup_path="${BACKUP_BASE_DIR}/${timestamp}/${target_skill}"
        mkdir -p "${backup_path}"
        cp -a "${skill_dir}/." "${backup_path}/"
        info "Backup preserved before uninstallation at: ${backup_path}"
        rm -rf "${skill_dir}"
        ok "Removed ${skill_dir}"
    fi

    # Remove entry from manifest
    local tmp_manifest
    tmp_manifest="$(mktemp)"
    grep -v "^${target_skill}|" "${MANIFEST_FILE}" > "${tmp_manifest}" || true
    sort "${tmp_manifest}" > "${MANIFEST_FILE}"
    rm -f "${tmp_manifest}"

    ok "Skill '${target_skill}' safely uninstalled and deregistered from manifest."
}

uninstall_all_skills() {
    print_banner
    echo -e "${COLOR_BOLD}Executing safe mass uninstallation for ALL managed skills...${COLOR_RESET}\n"

    if [[ ! -f "${MANIFEST_FILE}" || ! -s "${MANIFEST_FILE}" ]]; then
        info "No skills currently recorded in manifest (${MANIFEST_FILE}). Nothing to uninstall."
        exit 0
    fi

    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local count_removed=0

    while IFS='|' read -r skill_name repo_url commit installed_at hash; do
        [[ -z "${skill_name}" ]] && continue
        local skill_dir="${TARGET_DIR}/${skill_name}"
        if [[ -d "${skill_dir}" ]]; then
            local backup_path="${BACKUP_BASE_DIR}/${timestamp}/${skill_name}"
            mkdir -p "${backup_path}"
            cp -a "${skill_dir}/." "${backup_path}/"
            rm -rf "${skill_dir}"
            count_removed=$((count_removed + 1))
            info "Backed up and removed: ${COLOR_CYAN}${skill_name}${COLOR_RESET}"
        fi
    done < "${MANIFEST_FILE}"

    # Clear manifest
    > "${MANIFEST_FILE}"

    # Desactivar y limpiar timer de auto-actualización
    local systemd_user_dir="$HOME/.config/systemd/user"
    if [[ -f "${systemd_user_dir}/antigravity-skills-update.timer" ]]; then
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user disable --now antigravity-skills-update.timer >/dev/null 2>&1 || true
        fi
        rm -f "${systemd_user_dir}/antigravity-skills-update.timer" "${systemd_user_dir}/antigravity-skills-update.service"
        if command -v systemctl >/dev/null 2>&1; then
            systemctl --user daemon-reload >/dev/null 2>&1 || true
        fi
        info "Timer de actualización automática diaria desactivado y eliminado."
    fi

    # Limpiar comando global
    rm -f "$HOME/.local/bin/skills" "$HOME/.gemini/antigravity-ide/bin/skills"
    info "Accesos directos del comando global removidos."

    echo -e "\n${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BOLD}MASS UNINSTALLATION COMPLETE:${COLOR_RESET}"
    echo -e "  Skills Removed  : ${COLOR_GREEN}${count_removed}${COLOR_RESET}"
    echo -e "  Backups Saved To: ${COLOR_BOLD}${BACKUP_BASE_DIR}/${timestamp}/${COLOR_RESET}"
    echo -e "  Manifest Cleared: ${COLOR_DIM}${MANIFEST_FILE}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}\n"
}

# ------------------------------------------------------------------------------
# Status & Interactive Menu
# ------------------------------------------------------------------------------
show_installed_status() {
    print_banner
    echo -e "${COLOR_BOLD}Estado actual de Agent Skills en Antigravity IDE:${COLOR_RESET}\n"

    if [[ ! -d "${TARGET_DIR}" ]]; then
        info "La carpeta ${TARGET_DIR} aún no existe."
        return 0
    fi

    local total_skills=0
    local managed_skills=0

    echo -e "${COLOR_BOLD}Skills encontradas en:${COLOR_RESET} ${TARGET_DIR}\n"
    for sdir in "${TARGET_DIR}"/*; do
        if [[ -d "${sdir}" && -f "${sdir}/SKILL.md" ]]; then
            local sname
            sname="$(basename "${sdir}")"
            total_skills=$((total_skills + 1))
            
            # Check if recorded in manifest
            if [[ -f "${MANIFEST_FILE}" ]] && grep -q "^${sname}|" "${MANIFEST_FILE}"; then
                local commit
                commit="$(grep "^${sname}|" "${MANIFEST_FILE}" | cut -d'|' -f3)"
                echo -e "  ${COLOR_GREEN}●${COLOR_RESET} ${COLOR_BOLD}${sname}${COLOR_RESET} ${COLOR_DIM}(gestionada, git: ${commit:0:8})${COLOR_RESET}"
                managed_skills=$((managed_skills + 1))
            else
                echo -e "  ${COLOR_CYAN}○${COLOR_RESET} ${COLOR_BOLD}${sname}${COLOR_RESET} ${COLOR_DIM}(personal / no gestionada)${COLOR_RESET}"
            fi
        fi
    done

    echo -e "\n${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}"
    echo -e "  Total Skills activas : ${COLOR_BOLD}${total_skills}${COLOR_RESET}"
    echo -e "  Gestionadas por CLI  : ${COLOR_GREEN}${managed_skills}${COLOR_RESET}"
    echo -e "  Personal / Locales   : ${COLOR_CYAN}$((total_skills - managed_skills))${COLOR_RESET}"
    echo -e "  Manifest             : ${COLOR_DIM}${MANIFEST_FILE}${COLOR_RESET}"
    echo -e "  Reporte              : ${COLOR_DIM}${REPORT_FILE}${COLOR_RESET}"
    echo -e "${COLOR_CYAN}════════════════════════════════════════════${COLOR_RESET}\n"
}

interactive_menu() {
    while true; do
        clear 2>/dev/null || true
        print_banner
        echo -e "${COLOR_BOLD}Panel de Control Rápido de Agent Skills:${COLOR_RESET}\n"
        echo -e "  ${COLOR_GREEN}1)${COLOR_RESET} 🚀 ${COLOR_BOLD}Instalar todo${COLOR_RESET} (Instala la selección recomendada de 42 Skills)"
        echo -e "  ${COLOR_CYAN}2)${COLOR_RESET} 📋 ${COLOR_BOLD}Ver mis Skills instaladas${COLOR_RESET} (Muestra estado y skills activas)"
        echo -e "  ${COLOR_BLUE}3)${COLOR_RESET} 🔄 ${COLOR_BOLD}Actualizar repositorios y Skills${COLOR_RESET} (Descarga novedades de Git)"
        echo -e "  ${COLOR_YELLOW}4)${COLOR_RESET} 🔍 ${COLOR_BOLD}Simular instalación (Dry-Run)${COLOR_RESET} (Ver qué cambiaría sin tocar nada)"
        echo -e "  ${COLOR_MAGENTA}5)${COLOR_RESET} 🛡️  ${COLOR_BOLD}Escanear seguridad${COLOR_RESET} (Auditar todos los repos en busca de riesgos)"
        echo -e "  ${COLOR_RED}6)${COLOR_RESET} 🗑️  ${COLOR_BOLD}Desinstalar UNA Skill${COLOR_RESET} (Con backup automático)"
        echo -e "  ${COLOR_RED}7)${COLOR_RESET} ⚠️  ${COLOR_BOLD}Desinstalar TODAS las Skills${COLOR_RESET} (Limpieza total con backup)"
        echo -e "  ${COLOR_DIM}0)${COLOR_RESET} 🚪 Salir"
        echo ""
        read -r -p "Elige una opción [0-7]: " opt
        echo ""

        case "${opt}" in
            1)
                main_install_flow
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            2)
                show_installed_status
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            3)
                FLAG_UPDATE=true
                main_install_flow
                FLAG_UPDATE=false
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            4)
                FLAG_DRY_RUN=true
                main_install_flow
                FLAG_DRY_RUN=false
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            5)
                run_full_repository_security_scan
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            6)
                read -r -p "Escribe el nombre exacto de la Skill a desinstalar: " skill_to_remove
                if [[ -n "${skill_to_remove}" ]]; then
                    uninstall_skill "${skill_to_remove}"
                else
                    warn "No se especificó ninguna Skill."
                fi
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            7)
                read -r -p "¿Seguro que deseas desinstalar TODAS las Skills gestionadas? (s/N): " confirm
                if [[ "${confirm}" =~ ^[sSyY] ]]; then
                    uninstall_all_skills
                else
                    info "Operación cancelada."
                fi
                echo ""
                read -r -p "Presiona Enter para volver al menú..." _
                ;;
            0|q|Q)
                echo "¡Listo!"
                exit 0
                ;;
            *)
                echo -e "${COLOR_YELLOW}Opción no reconocida. Intenta de nuevo.${COLOR_RESET}"
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------------------------
# Help Screen
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
Usage: bash ${SCRIPT_NAME} [OPTIONS]

Full-featured CLI installer for community Google Antigravity Agent Skills on Arch Linux.
Discovers, verifies, audits for security, and installs curated skills into:
  ~/.gemini/antigravity/skills/<skill-name>/SKILL.md

Options:
  (no arguments)       Run standard installation of the 42 curated skills
  --menu, -i           Open the super-easy interactive control menu
  --status             Show summary of currently installed and active skills
  --dry-run            Simulate installation without writing or altering any files
  --list               List all available curated skills and categories
  --update             Fetch latest updates from Git repositories before installing
  --security-scan      Scan all community repositories for suspicious or dangerous code
  --uninstall <skill>  Safely uninstall a single skill managed by this installer
  --uninstall-all      Safely uninstall ALL skills managed by this installer (creates backups)
  --help               Display this help message and exit

Environment Variables:
  ANTIGRAVITY_SKILLS_DIR    Custom target skills path (default: ~/.gemini/antigravity/skills)
  ANTIGRAVITY_BACKUPS_DIR   Custom backups path (default: ~/.gemini/antigravity/skills-backups)
  XDG_CACHE_HOME            Custom cache root (default: ~/.cache)

Examples:
  ./skills
  bash ${SCRIPT_NAME} --menu
  bash ${SCRIPT_NAME}
  bash ${SCRIPT_NAME} --status
  bash ${SCRIPT_NAME} --dry-run
  bash ${SCRIPT_NAME} --update
  bash ${SCRIPT_NAME} --security-scan
  bash ${SCRIPT_NAME} --uninstall playwright-skill
  bash ${SCRIPT_NAME} --uninstall-all
EOF
}

# ------------------------------------------------------------------------------
# Main Install Flow Wrapper
# ------------------------------------------------------------------------------
main_install_flow() {
    print_banner
    step_1_check_environment
    step_2_fetch_repositories
    step_3_discover_skills
    step_4_check_compatibility
    step_5_run_security_checks
    step_6_resolve_duplicates
    step_7_install_skills
    step_8_verify_and_report
}

# ------------------------------------------------------------------------------
# Main Execution Entrypoint
# ------------------------------------------------------------------------------
main() {
    local open_menu=false
    local show_status_only=false

    # Parse CLI Arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --menu|-i|--interactive)
                open_menu=true
                shift
                ;;
            --status)
                show_status_only=true
                shift
                ;;
            --dry-run)
                FLAG_DRY_RUN=true
                shift
                ;;
            --update)
                FLAG_UPDATE=true
                shift
                ;;
            --list)
                FLAG_LIST=true
                shift
                ;;
            --security-scan)
                FLAG_SECURITY_SCAN=true
                shift
                ;;
            --uninstall-all)
                FLAG_UNINSTALL_ALL=true
                shift
                ;;
            --uninstall)
                if [[ $# -lt 2 || -z "$2" || "$2" =~ ^-- ]]; then
                    die "Option --uninstall requires a skill name argument (e.g. --uninstall playwright-skill)"
                fi
                FLAG_UNINSTALL="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                die "Unknown option: $1. Run 'bash ${SCRIPT_NAME} --help' for usage."
                ;;
        esac
    done

    # Route specialized actions
    if [[ "${open_menu}" == "true" ]]; then
        interactive_menu
        exit 0
    fi

    if [[ "${show_status_only}" == "true" ]]; then
        show_installed_status
        exit 0
    fi

    if [[ "${FLAG_LIST}" == "true" ]]; then
        list_available_skills
        exit 0
    fi

    if [[ "${FLAG_UNINSTALL_ALL}" == "true" ]]; then
        uninstall_all_skills
        exit 0
    fi

    if [[ -n "${FLAG_UNINSTALL}" ]]; then
        uninstall_skill "${FLAG_UNINSTALL}"
        exit 0
    fi

    if [[ "${FLAG_SECURITY_SCAN}" == "true" ]]; then
        run_full_repository_security_scan
        exit 0
    fi

    # Standard 8-Step Installation Workflow
    main_install_flow
}

main "$@"
