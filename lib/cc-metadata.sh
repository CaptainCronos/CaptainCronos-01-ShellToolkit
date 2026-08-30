#!/usr/bin/env bash
#
# ==============================================================================
# Captain Cronos Shell Toolkit
# ------------------------------------------------------------------------------
# Script      : cc-metadata.sh
# Version     : reads VERSION
# Category    : Core
# Requires    : bash
# Repository  : CaptainCronos-01-ShellToolkit
# Purpose     : Shared command metadata and registry helpers.
# ==============================================================================

cc_command_dir() {
    echo "$PROJECT_ROOT/tools/commands"
}

cc_command_list() {
    find "$(cc_command_dir)" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | LC_ALL=C sort
}

cc_metadata_field() {
    local file="$1"
    local field="$2"
    awk -v field="$field" '
        $0 ~ "^# " field "[[:space:]]*:" {
            sub("^# " field "[[:space:]]*:[[:space:]]*", "")
            print
            exit
        }
    ' "$file"
}

cc_command_file() {
    echo "$(cc_command_dir)/$1"
}

cc_infer_category() {
    case "$1" in
        config|registry|version|install|toolkit-update) echo "Core" ;;
        docs|helpme-refresh) echo "Documentation" ;;
        release|baseline|defaults) echo "Engineering" ;;
        repo|repos|gitflow|status) echo "Repository" ;;
        verify|doctor) echo "Diagnostics" ;;
        drives|smart) echo "Storage" ;;
        kernel|kernel-cleanup) echo "Maintenance" ;;
        dev-update|system-update|update|monthly-health|monthly-health-timer|maintenance|reports) echo "Maintenance" ;;
        *) echo "General" ;;
    esac
}

cc_command_metadata() {
    local cmd="$1"
    local file category requires script version purpose repository
    file="$(cc_command_file "$cmd")"
    script="$(cc_metadata_field "$file" "Script")"
    version="$(cc_metadata_field "$file" "Version")"
    purpose="$(cc_metadata_field "$file" "Purpose")"
    category="$(cc_metadata_field "$file" "Category")"
    requires="$(cc_metadata_field "$file" "Requires")"
    repository="$(cc_metadata_field "$file" "Repository")"

    [ -n "$script" ] || script="$cmd"
    [ -n "$version" ] || version="unknown"
    [ -n "$purpose" ] || purpose="unknown"
    [ -n "$category" ] || category="$(cc_infer_category "$cmd")"
    [ -n "$requires" ] || requires="bash"
    [ -n "$repository" ] || repository="CaptainCronos-01-ShellToolkit"

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$cmd" "$script" "$version" "$category" "$requires" "$repository" "$purpose"
}

cc_registry_tsv() {
    local cmd
    while read -r cmd; do
        [ -n "$cmd" ] || continue
        cc_command_metadata "$cmd"
    done < <(cc_command_list)
}

cc_registry_markdown() {
    echo "| Command | Version | Category | Requires | Purpose |"
    echo "|---|---|---|---|---|"
    cc_registry_tsv | while IFS=$'\t' read -r cmd script version category requires repository purpose; do
        echo "| cc $cmd | $version | $category | $requires | $purpose |"
    done
}

# Public CLI contracts. These tables are the authoritative discovery layer for
# dispatcher validation, contextual switch help, generated documentation, and
# contract tests. Fields are pipe-delimited so descriptions remain readable in
# Bash. Parser behavior remains implemented by each command; tests validate the
# contract against representative parser behavior and obvious static drift.
cc_contract_commands() {
    cat <<'EOF_CONTRACTS'
about|flat-no-switches|cc about|Show toolkit overview, components, and documentation locations.|none
asset|namespace|cc asset <subcommand> [arguments]|Manage local lifecycle asset inventory records.|namespace
audit|namespace-with-switches|cc audit [summary|commands] [switches]; cc audit fix [switches]|Audit command consistency and optionally repair managed command metadata.|namespace
baseline|flat-no-switches|cc baseline|Capture operating-system baseline shell files.|none
capability|namespace|cc capability [list|check NAME]|Resolve core, program, and plugin-provided capabilities.|namespace
config|namespace|cc config <subcommand> [arguments]|Read or update toolkit configuration.|namespace
defaults|flat-no-switches|cc defaults|Promote active shell files into defaults/v1.|none
deps|namespace|cc deps [subcommand] [arguments]|Show dependency status by command or profile.|namespace
dev-update|flat-with-switches|cc dev-update [TARGET] [switches]|Review or apply supported developer package-manager updates.|any
docs|namespace-with-switches|cc docs [subcommand] [switches]|Generate, lint, or verify toolkit documentation.|namespace
doctor|flat-with-switches|cc doctor [switches]|Run repository, installation, kernel, and host health checks.|none
drive-burnin|namespace|cc drive-burnin [subcommand] DEVICE|Run the non-destructive drive burn-in workflow framework.|namespace-or-any
drive-inventory|namespace|cc drive-inventory [table|csv|markdown]|Show read-only physical drive inventory.|namespace
drive-qualify|namespace-with-switches|cc drive-qualify [subcommand] [switches] DEVICE|Run non-destructive drive qualification.|namespace-or-any
drive-report|flat-no-switches|cc drive-report DEVICE|Archive a drive report and update its asset record.|any
drive-smart|flat-no-switches|cc drive-smart DEVICE|Show a concise SMART health summary.|any
drive-test|namespace|cc drive-test <subcommand> DEVICE|Start or inspect SMART self-tests.|namespace
drives|flat-no-switches|cc drives|Show physical devices, filesystems, labels, usage, and mounts.|none
env|namespace-with-switches|cc env [subcommand] [switches]|Inspect or repair host identity, shell files, and PATH health.|namespace
framework|namespace|cc framework [subcommand]|Inspect or verify framework milestone status.|namespace
gitflow|interactive|cc gitflow [REPOSITORY]|Launch the interactive Captain Cronos Git assistant.|any
helpme-refresh|flat-with-switches|cc helpme-refresh [switches]|Preview or replace the installed helpme function.|none
init|interactive|cc init [switches]|Initialize a portable host identity, optionally interactively.|none
install|flat-with-switches|cc install [switches]|Install or update only the active cc launcher.|none
kernel|namespace|cc kernel <subcommand> [switches]|Inspect kernel state, artifacts, health, dependencies, and cleanup candidates.|namespace
kernel-cleanup|compatibility-wrapper|cc kernel-cleanup [switches]|Compatibility entry point for cc kernel cleanup.|none
maintenance|namespace-with-switches|cc maintenance [subcommand] [switches]|Inspect persistent toolkit resource ownership and retention.|namespace
monthly-health|flat-with-switches|cc monthly-health [switches]|Generate a host health and maintenance report without kernel cleanup.|none
monthly-health-timer|namespace|cc monthly-health-timer <subcommand>|Manage the optional user-scoped monthly-health timer.|namespace
platform|namespace|cc platform [summary|capabilities]|Show platform identity and capabilities.|namespace
plugin|namespace|cc plugin [list|status|info ID|run ID OPERATION]|Inspect plugins or explicitly run one validated entrypoint.|namespace
programs|namespace|cc programs [subcommand] [arguments]|Report configured semantic program interfaces.|namespace
prompt|interactive|cc prompt [TEMPLATE]|Run the interactive, metadata-discovered prompt engine.|any
registry|namespace|cc registry [table|tsv|markdown]|Show the command header metadata registry.|namespace
release|namespace-with-switches|cc release [subcommand] [switches]|Plan or check the release workflow.|namespace
repo|flat-no-switches|cc repo|Show the current repository path, branch, and origin.|none
repos|namespace-with-switches|cc repos [subcommand] [switches]|Inventory or conservatively manage local Git repositories.|namespace
reports|namespace-with-switches|cc reports [subcommand] [switches]|Inspect and conservatively prune persistent report history.|namespace
roadmap|flat-no-switches|cc roadmap [markdown]|Show the canonical project roadmap.|any
selftest|flat-with-switches|cc selftest [switches]|Run the toolkit engineering self-test suite.|none
smart|flat-with-switches|cc smart [DEVICE] [switches]|Show storage and SMART detail, optionally for one device.|any
status|flat-no-switches|cc status|Show repository branch, origin, commits, and worktree status.|none
storage|namespace|cc storage <subcommand> [arguments]|Route storage inventory, SMART, testing, reporting, and workbench operations.|namespace
system-update|flat-with-switches|cc system-update [switches]|Preview or apply managed OS and packaged-application updates.|none
toolkit-update|flat-with-switches|cc toolkit-update [switches]|Preview or apply the toolkit Git and installer workflow.|none
update|namespace-with-switches|cc update [subcommand] [switches]|Run managed toolkit, system, kernel, health, and optional developer maintenance.|namespace
verify|namespace-with-switches|cc verify [subcommand] [switches]|Verify repository structure, syntax, and command permissions.|namespace
version|flat-no-switches|cc version|Show toolkit version and baseline information.|none
workbench|namespace-with-switches|cc workbench [subcommand] [switches]|Inspect or prepare a live USB drive-qualification workbench.|namespace
EOF_CONTRACTS
}

cc_contract_switches() {
    cat <<'EOF_SWITCHES'
audit|--strict|0|Require executable bits plus Category and Requires headers.
audit/summary|--strict|0|Require executable bits plus Category and Requires headers.
audit/commands|--strict|0|Require executable bits plus Category and Requires headers.
audit/fix|--apply|0|Repair managed command metadata and executable bits; omission is preview-only. [default: preview]
config/migrate|--apply|0|Back up and atomically add the current schema marker; omission is preview-only. [default: preview]
dev-update|--dry-run|0|Report supported update operations without mutation. [default]
dev-update|--apply|0|Authorize only the developer ecosystem updates implemented as mutable.
dev-update|--status-only|0|Report manager availability and policy without running update commands.
docs|--apply|0|Write generated files; omission prints output without updating generated files.
docs|--out DIR|1|Use DIR instead of docs/generated as the output destination.
docs/build|--apply|0|Write every generated document; omission prints each output. [default: print only]
docs/build|--out DIR|1|Write or print relative to DIR instead of docs/generated.
docs/inventory|--apply|0|Write COMMAND_INVENTORY.md; omission prints it. [default: print only]
docs/inventory|--out DIR|1|Use DIR instead of docs/generated.
docs/reference|--apply|0|Write COMMAND_REFERENCE.md; omission prints it. [default: print only]
docs/reference|--out DIR|1|Use DIR instead of docs/generated.
docs/changelog|--apply|0|Write CHANGE_SUMMARY.md; omission prints it. [default: print only]
docs/changelog|--out DIR|1|Use DIR instead of docs/generated.
docs/lint|--apply|0|Write DOCS_LINT.md; omission prints the lint report. [default: print only]
docs/lint|--out DIR|1|Use DIR instead of docs/generated.
docs/check|--out DIR|1|Check generated documents under DIR; this subcommand never writes.
doctor|--full|0|Include storage inventory and SMART summary in diagnostics.
drive-qualify|--long|0|Start a SMART long self-test after the initial report instead of a short test.
drive-qualify/start|--long|0|Start a SMART long self-test instead of a short test.
env|--fix, --apply|0|Repair managed PATH startup configuration; inspection is the default.
env/path|--fix, --apply|0|Atomically repair only managed PATH configuration; cannot change the parent shell.
env/doctor|--fix, --apply|0|Repair managed PATH configuration after environment diagnostics.
helpme-refresh|--dry-run|0|Preview replacement of the installed helpme function. [default]
helpme-refresh|--apply|0|Authorize replacement of the managed helpme function block.
init|--apply|0|Authorize host identity and managed environment writes; omission is dry-run. [default: dry-run]
init|--interactive|0|Collect host identity choices interactively.
init|--selftest|0|Run the engineering selftest after initialization.
init|--host-id ID|1|Set the normalized Captain Cronos host identifier.
init|--role ROLE|1|Select a supported host role.
init|--profile PROFILE|1|Select a supported platform profile.
install|--dry-run|0|Preview launcher installation without changing files. [default]
install|--apply|0|Explicitly authorize launcher installation or update.
install|--force|0|Reinstall the launcher even when the installed copy already matches.
kernel/cleanup|--dry-run|0|Preview obsolete-kernel package removal without mutation. [default]
kernel/cleanup|--apply|0|Explicitly authorize removal of eligible packages; protected kernels remain excluded.
kernel-cleanup|--dry-run|0|Preview obsolete-kernel package removal without mutation. [default]
kernel-cleanup|--apply|0|Delegate explicit removal authorization to cc kernel cleanup.
maintenance|--format FORMAT|1|Render inventory as a readable table or stable TSV. [default: table]
maintenance|--dry-run|0|Show the disabled cleanup plan without mutation.
maintenance/inventory|--format FORMAT|1|Render inventory as a readable table or stable TSV. [default: table]
maintenance/cleanup|--dry-run|0|Explicitly request the read-only cleanup preview; cleanup remains disabled.
monthly-health|--stdout|0|Write the report to standard output instead of a report file.
monthly-health|--file|0|Write the report file under the configured report directory. [default]
reports|--format FORMAT|1|Render list or prune as a readable table or stable TSV. [default: table]
reports/list|--format FORMAT|1|Render retained reports as a readable table or stable TSV. [default: table]
reports/prune|--format FORMAT|1|Render the bounded prune plan as a readable table or stable TSV. [default: table]
reports/prune|--apply|0|Explicitly authorize deletion of the displayed, verified current-host plan; omission is preview-only. [default: preview]
release|--apply|0|Accepted for workflow compatibility; release automation still does not bump, tag, or push.
repos|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos|--out FILE|1|Write inventory output to a .md or .csv file.
repos|--bundle-dir DIR|1|Use DIR for bundle backups. [default: ~/.captaincronos/repo-bundles]
repos|--message TEXT|1|Set the commit message required by the commit subcommand; --message=TEXT is also accepted.
repos|--apply|0|Authorize the selected mutating Git action; omission is dry-run. [default: dry-run]
repos/list|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/status|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/health|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/inventory|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/inventory|--out FILE|1|Write inventory to a .md or .csv file; omission prints the inventory.
repos/fetch|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/fetch|--apply|0|Authorize fetch and prune; omission is dry-run. [default: dry-run]
repos/pull|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/pull|--apply|0|Authorize fast-forward-only pulls of eligible repositories. [default: dry-run]
repos/sync|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/sync|--apply|0|Authorize fetch then fast-forward-only pull. [default: dry-run]
repos/backup|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/backup|--bundle-dir DIR|1|Use DIR for bundle backups. [default: ~/.captaincronos/repo-bundles]
repos/backup|--apply|0|Authorize Git bundle creation for eligible repositories. [default: dry-run]
repos/commit|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/commit|--message TEXT|1|Set the required commit message; --message=TEXT is also accepted.
repos/commit|--apply|0|Authorize commits in eligible dirty repositories. [default: dry-run]
repos/push|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/push|--apply|0|Authorize non-force pushes for eligible repositories. [default: dry-run]
repos/publish|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/publish|--apply|0|Authorize origin/main pushes for eligible clean main branches. [default: dry-run]
repos/verify|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
repos/doctor|--root PATH|1|Inspect repositories below PATH. [default: ~/GitHub]
selftest|--verbose|0|Show captured-output diagnostics without replaying successful stdout.
selftest|--json|0|Emit the selftest summary as JSON.
selftest|--debug|0|Emit intentional diagnostic events to standard error.
smart|--full|0|Show full SMART device information for the selected device.
smart|--logs|0|Show SMART log information for the selected device.
system-update|--dry-run|0|Preview package, Snap, and Flatpak operations without persistent mutation. [default]
system-update|--apply|0|Explicitly authorize implemented package, Snap, and Flatpak mutations.
toolkit-update|--dry-run|0|Inspect local state and preview update/install without Git or file mutation. [default]
toolkit-update|--apply|0|Authorize origin/main pull and the full installer apply path.
update|--dry-run|0|Preview every enabled maintenance stage without persistent mutation. [default]
update|--apply|0|Pass explicit mutation authorization only to enabled mutation-capable stages.
update|--toolkit-only|0|Run only the toolkit maintenance stage.
update|--system-only|0|Run system update and kernel cleanup stages only.
update|--health-only|0|Run only verification and health reporting stages.
update/dev|--dry-run|0|Preview supported developer ecosystem updates. [default]
update/dev|--apply|0|Authorize only implemented developer ecosystem mutations.
verify|--apply|0|Repair command executable permissions only when executable verification is selected.
verify/executable|--apply|0|Authorize repair of tools/commands executable permissions; omission is inspection-only.
workbench|--apply|0|Authorize supported workbench preparation; omission is dry-run. [default: dry-run]
workbench|--host-id ID|1|Set the initialized workbench host identifier.
workbench|--repo URL|1|Use URL as the toolkit repository source.
workbench|--target DIR|1|Use DIR as the parent checkout directory.
workbench|--no-selftest|0|Skip the post-preparation engineering selftest.
workbench/prepare|--apply|0|Authorize supported workbench preparation; omission is dry-run. [default: dry-run]
workbench/prepare|--host-id ID|1|Set the initialized workbench host identifier.
workbench/prepare|--repo URL|1|Use URL as the toolkit repository source.
workbench/prepare|--target DIR|1|Use DIR as the parent checkout directory.
workbench/prepare|--no-selftest|0|Skip the post-preparation engineering selftest.
EOF_SWITCHES
}

cc_contract_subcommands() {
    cat <<'EOF_SUBCOMMANDS'
asset|init|Initialize asset directories.|asset/init
asset|list|List assets, optionally by type.|asset/list
asset|show|Show one asset record.|asset/show
asset|path|Show an asset directory path.|asset/path
asset|search|Search asset records by type and query.|asset/search
asset|inventory|Show an inventory for one asset type.|asset/inventory
asset|create|Create an asset record from key=value fields.|asset/create
asset|set|Update fields on an existing asset record.|asset/set
asset|state|Change lifecycle state and optionally record a note.|asset/state
asset|history|Show one asset's lifecycle history.|asset/history
asset|retire|Retire an asset and optionally record a note.|asset/retire
asset|export|Export assets, optionally by type.|asset/export
audit|summary|Show the default command audit summary.|audit/summary
audit|commands|Show per-command audit detail.|audit/commands
audit|fix|Preview or apply managed audit repairs.|audit/fix
capability|list|List resolved core, program, and plugin capabilities.|capability/list
capability|check|Resolve one named capability and its semantic state.|capability/check
config|show|Show redacted configuration layers and their sources.|config/show
config|status|Show configuration ownership, schema, identity, and health.|config/status
config|validate|Validate configuration without writing.|config/validate
config|init|Initialize missing global configuration and stable identity.|config/init
config|get|Read one key with an optional default.|config/get
config|set|Atomically set one global user configuration key.|config/set
config|migrate|Preview or explicitly apply the supported schema migration.|config/migrate
deps|summary|Show the default dependency summary.|deps/summary
deps|command|Show dependencies for one registered command.|deps/command
deps|core|Show core dependencies.|deps/core
deps|docs|Show documentation dependencies.|deps/docs
deps|storage|Show storage dependencies.|deps/storage
deps|kernel|Show kernel dependencies and optional capabilities.|deps/kernel
deps|optional|Show optional dependencies.|deps/optional
docs|build|Generate every managed documentation output.|docs/build
docs|inventory|Generate the command inventory.|docs/inventory
docs|reference|Generate the command reference including switch contracts.|docs/reference
docs|changelog|Generate the recent change summary.|docs/changelog
docs|lint|Check command headers and Bash syntax.|docs/lint
docs|check|Verify generated documents are current; always read-only.|docs/check
drive-burnin|plan|Show the intended acceptance workflow.|drive-burnin/plan
drive-burnin|start|Capture a report and begin non-destructive qualification.|drive-burnin/start
drive-burnin|status|Show current SMART self-test status.|drive-burnin/status
drive-inventory|table|Render the default table format.|drive-inventory/table
drive-inventory|csv|Render CSV inventory.|drive-inventory/csv
drive-inventory|markdown|Render Markdown inventory.|drive-inventory/markdown
drive-qualify|start|Capture pre-test state and start SMART qualification.|drive-qualify/start
drive-qualify|status|Show SMART qualification status.|drive-qualify/status
drive-qualify|complete|Capture final state and qualify a healthy asset.|drive-qualify/complete
drive-test|status|Show SMART self-test status and recent log.|drive-test/status
drive-test|short|Start a SMART short self-test.|drive-test/short
drive-test|long|Start a SMART long self-test.|drive-test/long
drive-test|abort|Use the retained compatibility abort handler.|drive-test/abort
env|summary|Show the environment summary.|env/summary
env|path|Inspect or repair managed PATH state.|env/path
env|shell|Inspect managed shell-file state.|env/shell
env|host|Show resolved host identity.|env/host
env|doctor|Run environment diagnostics and optionally repair PATH.|env/doctor
framework|status|Show framework milestone progress.|framework/status
framework|checklist|Print the 1.3 completion checklist.|framework/checklist
framework|verify|Run framework quality gates.|framework/verify
kernel|status|Show kernel state and boot filesystem usage.|kernel/status
kernel|help|Show kernel namespace help.|kernel/help
kernel|list|List installed kernels and protection state.|kernel/list
kernel|running|Show the running release and matching packages.|kernel/running
kernel|platform|Show kernel platform support.|kernel/platform
kernel|capabilities|Alias for platform.|kernel/platform
kernel|artifacts|Correlate packages and boot artifacts.|kernel/artifacts
kernel|health|Evaluate package and artifact consistency read-only.|kernel/health
kernel|cleanup|Preview or apply protected obsolete-kernel cleanup.|kernel/cleanup
kernel|deps|Show kernel-management dependencies.|kernel/deps
kernel|dependencies|Alias for deps.|kernel/deps
maintenance|status|Summarize persistent resource accounting and cleanup state.|maintenance/status
maintenance|inventory|Inventory persistent resources by subsystem, class, policy, and root.|maintenance/inventory
maintenance|retention|Explain retention classes, ownership rules, and decision gates.|maintenance/retention
maintenance|cleanup|Preview the disabled cleanup policy; no apply interface exists.|maintenance/cleanup
monthly-health-timer|status|Show optional user timer state.|monthly-health-timer/status
monthly-health-timer|retire|Retire the standalone timer configuration.|monthly-health-timer/retire
monthly-health-timer|run-once|Run monthly health once.|monthly-health-timer/run-once
monthly-health-timer|install-standalone|Install the optional standalone user timer.|monthly-health-timer/install-standalone
monthly-health-timer|enable|Enable the optional user timer.|monthly-health-timer/enable
monthly-health-timer|disable|Disable the optional user timer.|monthly-health-timer/disable
platform|summary|Show the platform summary.|platform/summary
platform|capabilities|Show detected platform capabilities.|platform/capabilities
plugin|list|List validated local plugins and semantic state.|plugin/list
plugin|status|Alias for the validated plugin inventory.|plugin/status
plugin|info|Show validated details for one plugin ID.|plugin/info
plugin|run|Revalidate and explicitly execute one exact plugin entrypoint.|plugin/run
programs|check|Check required and optional program interfaces.|programs/check
programs|show|Show the implementation for one capability.|programs/show
registry|table|Render the metadata registry as a table.|registry/table
registry|tsv|Render tab-separated registry data.|registry/tsv
registry|markdown|Render the registry as Markdown.|registry/markdown
release|plan|Show the release workflow checklist.|release/plan
release|check|Run pre-release verification checks.|release/check
repos|list|List detected Git repositories.|repos/list
repos|status|Show the repository dashboard.|repos/status
repos|health|Show health-only dashboard and summary.|repos/health
repos|inventory|Generate a repository inventory.|repos/inventory
repos|fetch|Fetch and prune; dry-run by default.|repos/fetch
repos|pull|Pull fast-forward-only for clean repositories; dry-run by default.|repos/pull
repos|sync|Fetch then fast-forward-only pull; dry-run by default.|repos/sync
repos|backup|Create Git bundle backups; dry-run by default.|repos/backup
repos|commit|Commit dirty repositories with a required message; dry-run by default.|repos/commit
repos|push|Push eligible branches without force; dry-run by default.|repos/push
repos|publish|Push eligible clean main branches; dry-run by default.|repos/publish
repos|verify|Run cc verify in toolkit repositories.|repos/verify
repos|doctor|Run cc doctor in toolkit repositories.|repos/doctor
reports|status|Show current-host report lifecycle health and retained totals.|reports/status
reports|list|List recognized retained reports and policy state.|reports/list
reports|prune|Preview or explicitly apply a bounded current-host report plan.|reports/prune
storage|inventory|Delegate to read-only drive inventory.|storage/inventory
storage|help|Show storage namespace help.|storage/help
storage|drives|Delegate to mounted and installed device reporting.|storage/drives
storage|smart|Delegate to concise SMART reporting.|storage/smart
storage|test|Delegate to SMART self-test operations.|storage/test
storage|report|Delegate to archived drive reporting.|storage/report
storage|qualify|Delegate to non-destructive qualification.|storage/qualify
storage|burnin|Delegate to the burn-in workflow framework.|storage/burnin
storage|burn-in|Alias for burnin.|storage/burnin
storage|workbench|Delegate to workbench inspection or preparation.|storage/workbench
storage|deps|Show storage dependency status.|storage/deps
storage|dependencies|Alias for deps.|storage/deps
storage|status|Show workbench-oriented storage status.|storage/status
update|dev|Target supported developer package managers.|update/dev
update|developer|Alias for dev.|update/dev
update|developers|Alias for dev.|update/dev
update|npm|Target npm global packages.|update/dev
update|pipx|Target pipx applications.|update/dev
update|pip|Report pip policy; mutation remains disabled.|update/dev
update|cargo|Report cargo policy; mutation remains disabled.|update/dev
update|go|Report Go policy; mutation remains disabled.|update/dev
update|gem|Report RubyGems policy; mutation remains disabled.|update/dev
verify|all|Run repository verification.|verify/all
verify|executable|Inspect or repair command executable permissions.|verify/executable
workbench|prepare|Inspect or prepare the workbench.|workbench/prepare
workbench|status|Show workbench status.|workbench/status
EOF_SUBCOMMANDS
}

cc_contract_command_row() {
    local command_name="$1"
    # Consume the complete producer.  An early-exiting consumer can close the
    # pipe while the contract here-document is still being written; pipefail
    # then turns a successful lookup into a timing-dependent SIGPIPE failure.
    cc_contract_commands | awk -F '|' -v command_name="$command_name" \
        '$1 == command_name && !found { row=$0; found=1 } END { if (found) print row }'
}

cc_contract_subcommand_row() {
    local command_name="$1" subcommand="$2"
    cc_contract_subcommands | awk -F '|' -v command_name="$command_name" -v subcommand="$subcommand" \
        '$1 == command_name && $2 == subcommand && !found { row=$0; found=1 } END { if (found) print row }'
}
