#!/bin/bash
# DeepSeek CLI with balance check

API_KEY="sk-3e4f3606907441dfb38f5171037d321b"

# Check balance
check_balance() {
    echo "Checking API key balance..."
    
    response=$(curl -s https://api.deepseek.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $API_KEY" \
      -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"test"}],"temperature":0.7}')
    
    if echo "$response" | grep -q "Insufficient Balance"; then
        echo "❌ ERROR: Insufficient Balance"
        echo ""
        echo "Your DeepSeek API key has no credits left."
        echo ""
        echo "Solutions:"
        echo "1. Add credits at: https://platform.deepseek.com/billing"
        echo "2. Use a free alternative (see below)"
        echo ""
        echo "Free alternatives:"
        echo "  • Ollama (local models): ./ollama-chat.sh"
        echo "  • Google Gemini: ./gemini-chat.sh"
        echo "  • Hugging Face: ./hf-chat.sh"
        return 1
    elif echo "$response" | grep -q "choices"; then
        echo "✅ API key has balance available!"
        return 0
    else
        echo "❌ Unknown error"
        echo "Response: $response"
        return 1
    fi
}

# If you have balance, use this
if check_balance; then
    echo "API is working! You can use your scripts."
else
    echo "Please fix the balance issue first."
fi
