#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# Check if $DOMAIN is set
if [ -z "${DOMAIN:-}" ]; then
  echo -e "You did not set the \$DOMAIN variable at runtime. No certificate will be registered.\n"
  echo -e "If you want to define it on the command line, here is an example:\n"
  echo -e "docker run -d -p 80:80 -p 443:443 -e DOMAIN=webminerpool-5qek.onrender.com\n"
  exit 1
fi

# Optional SSL setup
if [ "${SSL_ENABLED:-false}" == "true" ]; then
  CERT_DIR="/root/.acme.sh/${DOMAIN}"
  CERT_FILE="${CERT_DIR}/${DOMAIN}.cer"

  # Check if certificate exists and is valid
  if [[ ! -f "$CERT_FILE" ]] || ! openssl x509 -checkend 0 -in "$CERT_FILE"; then
    echo "Certificate not found or expired for $DOMAIN. Issuing a new certificate..."

    # Generate SSL cert
    /root/.acme.sh/acme.sh --issue --standalone -d "$DOMAIN" -d "www.${DOMAIN}"

    # Check if the certificate was successfully generated
    if [[ -f "$CERT_FILE" ]]; then
      echo "Certificate successfully generated. Creating PFX file..."
      
      # Generate pfx
      openssl pkcs12 -export -out /webminerpool/certificate.pfx \
        -inkey "${CERT_DIR}/${DOMAIN}.key" \
        -in "$CERT_FILE" \
        -certfile "${CERT_DIR}/fullchain.cer" \
        -passin pass:miner -passout pass:miner
    else
      echo "Failed to generate certificate. Exiting..."
      exit 1
    fi
  else
    echo "Valid certificate already exists for $DOMAIN. Skipping generation."
  fi
else
  echo "SSL generation is disabled. Starting the server without SSL..."
fi

# Start server
pushd /webminerpool || exit 1
./Server
popd
