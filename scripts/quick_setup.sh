#!/bin/bash

# Quick Setup Script for Demo Account
# This script will guide you through the setup process

echo "🚀 DanceRang Demo Account Setup"
echo "================================"
echo ""

# Check if service account key exists
if [ -f "functions/serviceAccountKey.json" ]; then
    echo "✅ Service account key found!"
    echo ""
    echo "📦 Running setup script..."
    node scripts/setup_demo_simple.js
else
    echo "❌ Service account key NOT found!"
    echo ""
    echo "📋 You need to download it first. Follow these steps:"
    echo ""
    echo "1. Open this URL in your browser:"
    echo "   https://console.firebase.google.com/project/dancerang-733ea/settings/serviceaccounts/adminsdk"
    echo ""
    echo "2. Click 'Generate New Private Key' button"
    echo "3. Click 'Generate Key' in the popup"
    echo "4. Save the downloaded file as: functions/serviceAccountKey.json"
    echo ""
    echo "5. After saving, run this command again:"
    echo "   ./scripts/quick_setup.sh"
    echo ""
    echo "OR run directly:"
    echo "   node scripts/setup_demo_simple.js"
    echo ""
fi
