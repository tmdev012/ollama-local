#!/bin/bash
# Chat with local AI models using Ollama

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
fi

# List available models
echo "Available models:"
ollama list

# Simple chat function
chat() {
    local prompt="$*"
    
    if [ -z "$prompt" ]; then
        echo "Usage: ollama-chat.sh 'your question'"
        echo "Or:    ollama-chat.sh --interactive"
        return 1
    fi
    
    # Default model (change if you have others)
    MODEL="llama3.2"
    
    echo "🤖 Thinking..."
    ollama run "$MODEL" "$prompt"
}

# Main
if [ "$1" = "--interactive" ]; then
    echo "🤖 Ollama Interactive Mode"
    echo "Type 'exit' to quit"
    echo "========================"
    
    while true; do
        echo -n "👤 You: "
        read -r prompt
        
        if [[ "$prompt" =~ ^(exit|quit)$ ]]; then
            echo "👋 Goodbye!"
            break
        fi
        
        if [ -n "$prompt" ]; then
            ollama run llama3.2 "$prompt"
            echo
        fi
    done
else
    chat "$@"
fi
