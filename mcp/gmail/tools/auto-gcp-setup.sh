#!/bin/bash
# Automated GCP OAuth Setup

export PATH="/home/tmdev012/google-cloud-sdk/bin:$PATH"
PROJECT_ID="tm012-git-tracking"
CONFIG_DIR="/home/tmdev012/ollama-local/mcp/gmail/config"

echo "=== GCP Gmail OAuth Automated Setup ==="
echo ""

# Step 1: Auth
echo "[1/5] Authenticating with Google..."
gcloud auth login --project=$PROJECT_ID

# Step 2: Set project
echo ""
echo "[2/5] Setting project..."
gcloud config set project $PROJECT_ID

# Step 3: Enable Gmail API
echo ""
echo "[3/5] Enabling Gmail API..."
gcloud services enable gmail.googleapis.com

# Step 4: Create OAuth brand (consent screen)
echo ""
echo "[4/5] Creating OAuth consent screen..."
gcloud alpha iap oauth-brands create \
    --application_title="sashi-cli" \
    --support_email="tmdev012@outlook.com" 2>/dev/null || echo "Brand may already exist"

# Step 5: Create OAuth client
echo ""
echo "[5/5] Creating OAuth client credentials..."

# Using REST API to create OAuth client
ACCESS_TOKEN=$(gcloud auth print-access-token)

curl -s -X POST \
  "https://oauth2.googleapis.com/create-client" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "client_name": "sashi-cli",
    "client_type": "DESKTOP"
  }' > /tmp/oauth_response.json 2>/dev/null

if [ -s /tmp/oauth_response.json ]; then
    # Extract client_id and client_secret
    python3 << PYEOF
import json
import os

try:
    with open('/tmp/oauth_response.json') as f:
        data = json.load(f)

    if 'client_id' in data:
        creds = {
            "installed": {
                "client_id": data['client_id'],
                "client_secret": data['client_secret'],
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "redirect_uris": ["http://localhost"]
            }
        }
        with open('$CONFIG_DIR/credentials.json', 'w') as f:
            json.dump(creds, f, indent=2)
        print("Credentials saved!")
    else:
        print("API response:", json.dumps(data, indent=2))
        print("Manual download required")
except Exception as e:
    print(f"Error: {e}")
    print("Manual download required")
PYEOF
fi

# Check if we got credentials
if [ -f "$CONFIG_DIR/credentials.json" ]; then
    echo ""
    echo "=== SUCCESS ==="
    echo "Credentials saved to: $CONFIG_DIR/credentials.json"
    echo ""
    echo "Now run: ~/ollama-local/mcp/gmail/tools/gmail-setup"
else
    echo ""
    echo "=== Manual Step Required ==="
    echo "Opening OAuth client creation page..."
    xdg-open "https://console.cloud.google.com/apis/credentials/oauthclient?project=$PROJECT_ID"
    echo ""
    echo "1. Select: Desktop app"
    echo "2. Name: sashi-cli"
    echo "3. Click CREATE"
    echo "4. Click DOWNLOAD JSON"
    echo ""
    echo "Then run:"
    echo "mv ~/Downloads/client_secret_*.json $CONFIG_DIR/credentials.json"
fi
