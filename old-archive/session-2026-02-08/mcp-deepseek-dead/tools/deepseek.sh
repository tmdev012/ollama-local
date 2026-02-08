#!/bin/bash
# DeepSeek CLI - Simple bash version using curl

CONFIG_DIR="$HOME/.config/deepseek"
CONFIG_FILE="$CONFIG_DIR/api_key.txt"

# Load API key
load_api_key() {
    if [ -f "$CONFIG_FILE" ]; then
        API_KEY=$(cat "$CONFIG_FILE")
    elif [ -n "$DEEPSEEK_API_KEY" ]; then
        API_KEY="$DEEPSEEK_API_KEY"
    else
        API_KEY=""
    fi
}

# Save API key
save_api_key() {
    mkdir -p "$CONFIG_DIR"
    echo "$1" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    echo "✅ API key saved to $CONFIG_FILE"
}

# Simple chat
chat() {
    local prompt="$*"
    
    if [ -z "$API_KEY" ]; then
        echo "❌ No API key configured!"
        echo "Run: $0 --set-key YOUR_API_KEY"
        return 1
    fi
    
    # Escape quotes in prompt
    prompt=$(echo "$prompt" | sed 's/"/\\"/g')
    
    curl -s https://api.deepseek.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "{
        \"model\": \"deepseek-chat\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
        \"temperature\": 0.7,
        \"max_tokens\": 2000
      }" | jq -r '.choices[0].message.content'
}

# Stream chat
stream_chat() {
    local prompt="$*"
    
    if [ -z "$API_KEY" ]; then
        echo "❌ No API key configured!"
        return 1
    fi
    
    # Escape quotes
    prompt=$(echo "$prompt" | sed 's/"/\\"/g')
    
    echo -n "🤖 "
    
    curl -s -N https://api.deepseek.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d "{
        \"model\": \"deepseek-chat\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$prompt\"}],
        \"temperature\": 0.7,
        \"max_tokens\": 2000,
        \"stream\": true
      }" | while IFS= read -r line; do
        if [[ $line == data:* ]]; then
            if [[ $line == "data: [DONE]" ]]; then
                echo
                break
            fi
            # Extract content from JSON
            content=$(echo "$line" | sed 's/^data: //' | jq -r '.choices[0].delta.content // empty' 2>/dev/null || echo "")
            if [ -n "$content" ]; then
                echo -n "$content"
            fi
        fi
    done
}

# Interactive mode
interactive() {
    echo "🤖 DeepSeek Interactive Mode"
    echo "Type 'exit', 'quit', or 'bye' to end"
    echo "======================================"
    
    while true; do
        echo -n "👤 You: "
        read -r prompt
        
        if [[ "$prompt" =~ ^(exit|quit|bye)$ ]]; then
            echo "👋 Goodbye!"
            break
        fi
        
        if [ -n "$prompt" ]; then
            stream_chat "$prompt"
            echo
        fi
    done
}

# Main function
main() {
    load_api_key
    
    case "$1" in
        --set-key|-s)
            if [ -n "$2" ]; then
                save_api_key "$2"
            else
                echo "Usage: $0 --set-key YOUR_API_KEY"
            fi
            ;;
        --stream|-S)
            shift
            stream_chat "$@"
            ;;
        --interactive|-i)
            interactive
            ;;
        --help|-h)
            echo "DeepSeek CLI - Command Line Interface"
            echo ""
            echo "Usage:"
            echo "  $0 'your question here'     # Simple query"
            echo "  $0 --stream 'question'      # Streaming response"
            echo "  $0 --interactive            # Interactive chat"
            echo "  $0 --set-key API_KEY        # Set API key"
            echo "  $0 --help                   # Show this help"
            ;;
        "")
            echo "🤖 DeepSeek CLI"
            echo "Try: $0 'Hello, who are you?'"
            echo "Or:  $0 --help for more options"
            ;;
        *)
            chat "$@"
            ;;
    esac
}

# Run it
main "$@"
