#!/usr/bin/env bash
# Creates a self-signed code-signing identity, "Selby Local Signing", in the
# login keychain. scripts/build.sh signs with it when present.
#
# Why: an ad-hoc signature changes with every build, and macOS ties
# Accessibility and Automation grants (needed for "Safari (Private)") to the
# signature. A stable identity keeps those grants across reinstalls.
#
# Usage: scripts/make-signing-identity.sh
# Run it once, interactively: macOS asks for your login password to trust
# the certificate, and the first signing asks to allow codesign to use the
# key. Choose "Always Allow".
set -euo pipefail

NAME="Selby Local Signing"
if security find-identity -v -p codesigning 2>/dev/null | grep -q "\"$NAME\""; then
  echo "Identity \"$NAME\" already exists." >&2
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cat > "$WORK/openssl.cnf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
CONF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$WORK/openssl.cnf" \
  -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
openssl pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
  -passout pass:selby -out "$WORK/identity.p12"
# -T lets codesign use the private key without a prompt per build.
security import "$WORK/identity.p12" -P selby -T /usr/bin/codesign
# codesign refuses untrusted identities, so trust the certificate for code
# signing in this user's trust settings. This is the step that prompts.
security add-trusted-cert -r trustRoot -p codeSign "$WORK/cert.pem"
security find-identity -v -p codesigning | grep -q "\"$NAME\"" \
  || { echo "error: the identity is not valid; was the trust prompt declined?" >&2; exit 1; }
echo "Created \"$NAME\". scripts/build.sh will sign with it from now on." >&2
