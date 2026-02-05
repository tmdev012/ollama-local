#!/bin/bash
# Create Service Account for Gmail API (no browser automation needed)

export PATH="/home/tmdev012/google-cloud-sdk/bin:$PATH"
PROJECT_ID="tm012-git-tracking"
SA_NAME="sashi-gmail"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
CONFIG_DIR="/home/tmdev012/ollama-local/mcp/gmail/config"

echo "=== Service Account Setup for Gmail ==="
echo ""

# Enable APIs
echo "[1/4] Enabling Gmail API..."
gcloud services enable gmail.googleapis.com --project=$PROJECT_ID 2>/dev/null || echo "API may need manual enable"

# Create service account
echo "[2/4] Creating service account..."
gcloud iam service-accounts create $SA_NAME \
    --display-name="SASHI Gmail Access" \
    --project=$PROJECT_ID 2>/dev/null || echo "Service account may exist"

# Create key
echo "[3/4] Creating key file..."
gcloud iam service-accounts keys create "$CONFIG_DIR/service-account.json" \
    --iam-account=$SA_EMAIL \
    --project=$PROJECT_ID

if [ -f "$CONFIG_DIR/service-account.json" ]; then
    echo ""
    echo "[4/4] SUCCESS! Service account key saved."
    echo ""
    echo "NOTE: Service accounts can't access personal Gmail."
    echo "For personal Gmail, OAuth is required."
    echo ""
    echo "Options:"
    echo "1. Use Google Workspace (business Gmail) with domain-wide delegation"
    echo "2. Complete OAuth manually (3 clicks in browser)"
else
    echo ""
    echo "Service account creation failed."
    echo "OAuth is required for personal Gmail access."
fi
