#!/bin/bash
# Bash completion script for ralph.sh
#
# Installation:
#   Option 1: Source directly in your shell config
#     echo 'source /path/to/ralph-starter/completions/ralph.bash' >> ~/.bashrc
#
#   Option 2: Copy to system completions directory
#     sudo cp completions/ralph.bash /etc/bash_completion.d/ralph
#
#   Option 3: Copy to user completions directory
#     mkdir -p ~/.local/share/bash-completion/completions
#     cp completions/ralph.bash ~/.local/share/bash-completion/completions/ralph.sh

_ralph_completions() {
    local cur prev opts presets models log_formats
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Presets
    presets="launch spec plan build product"

    # Models
    models="opus sonnet haiku"

    # Log formats
    log_formats="text json"

    # All options
    opts="
        -h --help
        -f --file
        -p --prompt
        -m --model
        -n --max
        -s --spec
        -l --plan
        -1 --test
        -i --interactive
        -v --verbose
        --push
        --no-push
        --unlimited
        --dry-run
        --interactive-timeout
        --skip-checks
        --no-retry
        --max-retries
        --resume
        --list-sessions
        --log-dir
        --log-file
        --log-format
        --notify-webhook
        --no-summary
        --global-config
        --progress
        --source
        --context
        --output
        --artifact-spec
        --full-product
        --skip-product
        --launch-buffer
        --from-product
        -o --spec-output
        --force
    "

    # Handle options that take file paths
    case "${prev}" in
        -f|--file|-s|--spec|-l|--plan|--progress|--log-file|--global-config|--artifact-spec)
            # Complete file paths
            mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
            return 0
            ;;
        --log-dir|--source|--context|--output)
            # Complete directory paths
            mapfile -t COMPREPLY < <(compgen -d -- "${cur}")
            return 0
            ;;
        -m|--model)
            # Complete model names
            mapfile -t COMPREPLY < <(compgen -W "${models}" -- "${cur}")
            return 0
            ;;
        --log-format)
            # Complete log formats
            mapfile -t COMPREPLY < <(compgen -W "${log_formats}" -- "${cur}")
            return 0
            ;;
        -n|--max|--max-retries|--interactive-timeout|--launch-buffer)
            # These take numbers, no completion
            return 0
            ;;
        -p|--prompt|--notify-webhook)
            # These take strings, no completion
            return 0
            ;;
        -o|--spec-output)
            # Complete file paths for spec output
            mapfile -t COMPREPLY < <(compgen -f -- "${cur}")
            return 0
            ;;
        --from-product|--force|--full-product|--skip-product)
            # These are flags without arguments
            return 0
            ;;
    esac

    # If current word starts with -, complete options
    if [[ "${cur}" == -* ]]; then
        mapfile -t COMPREPLY < <(compgen -W "${opts}" -- "${cur}")
        return 0
    fi

    # Check if we already have a preset
    local has_preset=false
    for word in "${COMP_WORDS[@]}"; do
        case "${word}" in
            launch|spec|plan|build|product)
                has_preset=true
                break
                ;;
        esac
    done

    # If no preset yet, offer presets and options
    if [[ "${has_preset}" == false ]]; then
        mapfile -t COMPREPLY < <(compgen -W "${presets} ${opts}" -- "${cur}")
    else
        # After preset, offer options and numbers for iteration count
        mapfile -t COMPREPLY < <(compgen -W "${opts}" -- "${cur}")
    fi

    return 0
}

# Register completion for ralph.sh and common symlinks/aliases
complete -F _ralph_completions ralph.sh
complete -F _ralph_completions ./ralph.sh
complete -F _ralph_completions ralph
