#!/bin/bash
# OLLAMA SERVICE ALIASES | Group: ollama
alias ollama-up='sudo systemctl start ollama'
alias ollama-down='sudo systemctl stop ollama'
alias ollama-restart='sudo systemctl restart ollama'
alias ollama-logs='sudo journalctl -u ollama -f -n 50'
alias ollama-status='systemctl is-active ollama && ollama list'
