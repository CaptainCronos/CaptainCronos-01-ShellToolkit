#!/usr/bin/env bash
#
# Captain Cronos Shell Toolkit
# Script      : cc-requirements.sh
# Category    : Core
# Purpose     : Resolve conservative semantic role requirements and package plans.

if ! declare -F cc_capability_result >/dev/null 2>&1; then
    _cc_requirements_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    # shellcheck disable=SC1091
    source "$_cc_requirements_lib_dir/cc-capabilities.sh"
    # shellcheck disable=SC1091
    source "$_cc_requirements_lib_dir/cc-packages.sh"
    unset _cc_requirements_lib_dir
fi

cc_requirement_roles() { printf '%s\n' developer workstation workbench server nas laptop custom; }

cc_requirement_role_valid() { cc_requirement_roles | grep -Fxq -- "$1"; }

# role|capability|criticality.  Only requirements justified by existing workflows are declared.
cc_requirement_catalog() {
    cat <<'EOF_REQUIREMENTS'
workbench|smart|required
nas|smart|required
nas|zfs|optional
server|systemd|optional
developer|git|required
workstation|git|required
laptop|git|required
EOF_REQUIREMENTS
}

cc_requirement_provider_file() {
    local lib_dir
    lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    printf '%s/config/requirements.conf\n' "${TOOLKIT_ROOT:-${PROJECT_ROOT:-${lib_dir}/..}}"
}

cc_requirement_provider() {
    local capability="$1" manager="${2:-$(cc_platform_package_manager)}" file
    file="$(cc_requirement_provider_file)"
    [ -f "$file" ] || return 1
    awk -F'|' -v c="$capability" -v m="$manager" '$1==c && $2==m {print $3; exit}' "$file"
}

_cc_requirement_state() {
    local capability="$1" state provider detail package manager
    IFS=$'\t' read -r state _ provider detail < <(cc_capability_result "$capability")
    case "$state" in
        available) printf '%s\t%s\t%s\n' satisfied "$provider" "$detail" ;;
        disabled|unsupported) printf '%s\t%s\t%s\n' unsupported "$provider" "$detail" ;;
        incompatible) printf '%s\t%s\t%s\n' incompatible "$provider" "$detail" ;;
        unknown) printf '%s\t%s\t%s\n' unknown/unresolved "$provider" "$detail" ;;
        missing|unavailable|missing-dependency)
            manager="$(cc_platform_package_manager)"
            package="$(cc_requirement_provider "$capability" "$manager" || true)"
            if [ -n "$package" ] && [ "$manager" != none ] && _cc_pkg_is_available "$package" >/dev/null 2>&1; then
                printf '%s\t%s\t%s\n' missing/installable "$package" "provider for $manager"
            elif [ -n "$package" ] && [ "$manager" != none ]; then
                printf '%s\t%s\t%s\n' unknown/unresolved "$package" "package availability could not be safely confirmed"
            else printf '%s\t%s\t%s\n' unsupported "$provider" "$detail"; fi ;;
    esac
}

# role|capability|criticality|outcome|provider|detail
cc_requirements_resolve() {
    local role="$1" declared_role capability criticality outcome provider detail
    cc_requirement_role_valid "$role" || return 2
    while IFS='|' read -r declared_role capability criticality; do
        [ "$declared_role" = "$role" ] || continue
        IFS=$'\t' read -r outcome provider detail < <(_cc_requirement_state "$capability")
        if [ "$criticality" = optional ] && [ "$outcome" != satisfied ]; then outcome="optional/$outcome"; fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$role" "$capability" "$criticality" "$outcome" "$provider" "$detail"
    done < <(cc_requirement_catalog)
}

cc_requirements_summary() {
    local role="$1" criticality outcome failures=0 warnings=0 _rest
    while IFS=$'\t' read -r _ _ criticality outcome _rest; do
        case "$criticality:$outcome" in required:satisfied) ;; required:*) failures=$((failures + 1));; optional:*) warnings=$((warnings + 1));; esac
    done < <(cc_requirements_resolve "$role")
    if [ "$failures" -gt 0 ]; then printf 'FAIL\t%s required unresolved; %s optional non-satisfied\n' "$failures" "$warnings"; return 1; fi
    if [ "$warnings" -gt 0 ]; then printf 'WARN\t%s optional non-satisfied\n' "$warnings"; return 0; fi
    printf 'PASS\tall declared requirements satisfied\n'
}

# Applies only provider-backed required missing requirements. No refresh is performed.
cc_requirements_apply() {
    local role="$1" criticality outcome package capability unresolved=0 applied=0
    while IFS=$'\t' read -r _ capability criticality outcome package _; do
        [ "$criticality:$outcome" = required:missing/installable ] || continue
        _cc_pkg_install "$package" || unresolved=1
        applied=1
        IFS=$'\t' read -r outcome _ < <(_cc_requirement_state "$capability")
        [ "$outcome" = satisfied ] || unresolved=1
    done < <(cc_requirements_resolve "$role")
    [ "$applied" -gt 0 ] || true
    cc_requirements_summary "$role" >/dev/null || unresolved=1
    return "$unresolved"
}
