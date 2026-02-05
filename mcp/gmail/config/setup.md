# Gmail CLI Setup

## Step 1: Google Cloud Console

1. Go to: https://console.cloud.google.com/
2. Create new project: "ollama-local-gmail"
3. Enable Gmail API:
   - APIs & Services > Library > Gmail API > Enable

## Step 2: Create OAuth Credentials

1. APIs & Services > Credentials > Create Credentials > OAuth client ID
2. Application type: Desktop app
3. Download JSON → save as `~/.ollama-local/mcp/gmail/config/credentials.json`

## Step 3: Run Setup Script

```bash
~/ollama-local/mcp/gmail/tools/gmail-setup
```

## Step 4: Usage

```bash
# Search emails
sashi gmail search "claude chat"

# Get recent
sashi gmail recent 10

# Export to context
sashi gmail export "ai conversations" > context.txt
```
