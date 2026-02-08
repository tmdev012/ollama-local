#!/bin/bash
# PIPE SUPPORT ALIASES | Group: pipe
aipipe() { "${SASHI_HOME:-$HOME/ollama-local}/sashi" code "$1 $(cat -)"; }
alias analyze='aipipe "Analyze:"'
alias summarize='aipipe "Summarize:"'
alias explain='aipipe "Explain:"'
alias review='aipipe "Code review:"'
