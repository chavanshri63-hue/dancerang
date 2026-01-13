#!/bin/bash

# Android Keystore Creation Script
# This script creates a keystore for Android app signing

echo "🔐 Creating Android Release Keystore..."
echo ""

# Generate random password (same for both store and key - PKCS12 requirement)
KEYSTORE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
KEY_PASSWORD=$KEYSTORE_PASSWORD  # Same password for PKCS12 compatibility

echo "Generated password (save this securely!):"
echo "Keystore/Key Password: $KEYSTORE_PASSWORD"
echo ""

# Create keystore (using same password for store and key)
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -storepass "$KEYSTORE_PASSWORD" \
  -keypass "$KEY_PASSWORD" \
  -storetype PKCS12 \
  -dname "CN=DanceRang, OU=Development, O=DanceRang, L=City, ST=State, C=IN"

if [ $? -eq 0 ]; then
  echo ""
  echo "✅ Keystore created successfully: upload-keystore.jks"
  echo ""
  
  # Create key.properties file
  cat > key.properties << EOF
storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
EOF
  
  echo "✅ key.properties file created"
  echo ""
  echo "⚠️  IMPORTANT: Save this password securely!"
  echo "   Keystore/Key Password: $KEYSTORE_PASSWORD"
  echo ""
  echo "✅ Setup complete! You can now build release APK/AAB"
else
  echo "❌ Failed to create keystore"
  exit 1
fi

