#compdef ralph.sh ralph

# Zsh completion script for ralph.sh
#
# Installation (add to ~/.zshrc BEFORE compinit):
#
#   # Add completions to fpath from your project's submodule
#   fpath=(/path/to/your-project/ralph-starter/completions $fpath)
#   autoload -Uz compinit && compinit
#
#   # Recommended: alias for convenience (completions work automatically)
#   alias ralph='./ralph-starter/ralph.sh'

_ralph() {
    local -a presets models log_formats

    presets=(
        'dev:Run spec -> build pipeline for everyday features'
        'launch:Run product -> spec -> build pipeline for greenfield projects'
        'spec:Use PROMPT_spec.md for generating JSON specs from input'
        'plan:Use PROMPT_plan.md for architecture and planning tasks'
        'build:Use PROMPT_build.md for implementation tasks'
        'product:Use PROMPT_product.md for product artifact generation'
        'review:Codebase analysis producing findings JSON + Markdown report'
    )

    models=(
        'opus:Most capable model (default for plan/build/product)'
        'sonnet:Balanced capability and speed'
        'haiku:Fastest, most cost-effective'
    )

    log_formats=(
        'text:Human-readable log format (default)'
        'json:Structured JSON log format for log aggregation'
    )

    _arguments -C \
        '(-h --help)'{-h,--help}'[Show help message]' \
        '(-f --file)'{-f,--file}'[Use custom prompt file]:prompt file:_files' \
        '(-p --prompt)'{-p,--prompt}'[Use inline prompt string]:prompt string:' \
        '(-m --model)'{-m,--model}'[Model to use]:model:(($models))' \
        '(-n --max)'{-n,--max}'[Max iterations (default: 10)]:number:' \
        '(-s --spec)'{-s,--spec}'[Spec file path]:spec file:_files' \
        '(-l --plan)'{-l,--plan}'[Plan file path]:plan file:_files' \
        '(-1 --test)'{-1,--test}'[Test mode: single iteration, no push, ignore completion marker]' \
        '(-i --interactive)'{-i,--interactive}'[Prompt for confirmation between iterations]' \
        '(-v --verbose)'{-v,--verbose}'[Verbose mode: show prompt content, config precedence]' \
        '--push[Enable git push after iterations (default)]' \
        '--no-push[Disable git push]' \
        '--unlimited[Remove iteration limit (use with caution)]' \
        '--dry-run[Show config and exit without running Claude]' \
        '--interactive-timeout[Timeout for interactive prompt in seconds]:seconds:' \
        '--skip-checks[Skip pre-flight dependency checks]' \
        '--no-retry[Disable retry on transient failures]' \
        '--max-retries[Max retry attempts (default: 3)]:number:' \
        '--resume[Resume interrupted session from .ralph-session.json]' \
        '--list-sessions[List all resumable sessions]' \
        '--log-dir[Log directory path]:directory:_files -/' \
        '--log-file[Explicit log file path]:file:_files' \
        '--log-format[Log format: text or json]:format:(($log_formats))' \
        '--notify-webhook[Webhook URL for session notifications]:url:' \
        '--no-summary[Disable session summary report generation]' \
        '--global-config[Global config file path]:file:_files' \
        '--progress[Progress file path]:file:_files' \
        '--source[Source directory path]:directory:_files -/' \
        '--context[Product context directory]:directory:_files -/' \
        '--output[Product output directory]:directory:_files -/' \
        '--artifact-spec[Artifact spec file path]:file:_files' \
        '--dev-buffer[Build phase buffer for dev mode (default: 5)]:number:' \
        '--launch-buffer[Build phase buffer for launch mode (default: 5)]:number:' \
        '--from-product[Read input from product-output/ artifacts]' \
        '(-o --spec-output)'{-o,--spec-output}'[Output spec file path]:file:_files' \
        '--force[Overwrite existing output file]' \
        '--review-target[Target directory/glob to review]:directory:_files -/' \
        '--diff-base[Only review files changed since git ref]:ref:' \
        '--findings[Findings JSON output path]:file:_files' \
        '--report[Report Markdown output path]:file:_files' \
        '--fix-spec[Generate fix-spec tasks from findings]:file:_files' \
        '--focus[Comma-separated categories to analyze]:categories:' \
        '*:preset or iterations:(($presets))'
}

# Provide completion for ralph.sh and common invocation patterns
compdef _ralph ralph.sh ralph ./ralph.sh ./ralph-starter/ralph.sh
