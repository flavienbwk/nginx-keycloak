#!/bin/bash
set -e

# Load environment variables from .env file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    set -o allexport
    source "$ENV_FILE"
    set +o allexport
else
    echo "Error: $ENV_FILE file not found"
    exit 1
fi

# Variables
KEYCLOAK_URL="${KEYCLOAK_EXTERNAL_ENDPOINT}"
REALM="master"
CLIENT_ID="admin-cli"
USERNAME="${KEYCLOAK_USER}"
PASSWORD="${KEYCLOAK_PASSWORD}"
NEW_CLIENT_ID="${KEYCLOAK_CLIENT}"
REDIRECT_URI="${KEYCLOAK_LOGOUT_REDIRECT_URI}*"
ROLE_NAME="NginxApps-App1"
NEW_USER="demouser"
NEW_USER_PASSWORD="demopassword"

# Function to get admin token
get_admin_token() {
    curl -s -X POST "${KEYCLOAK_URL}/realms/${REALM}/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "username=${USERNAME}" \
        -d "password=${PASSWORD}" \
        -d 'grant_type=password' \
        -d "client_id=${CLIENT_ID}" | jq -r '.access_token'
}

# Get admin token
TOKEN=$(get_admin_token)

# Create client if it doesn't exist
create_client() {
    if ! curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${NEW_CLIENT_ID}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -e '.[0]' > /dev/null; then
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
                "clientId": "'${NEW_CLIENT_ID}'",
                "redirectUris": ["'${REDIRECT_URI}'"],
                "publicClient": false,
                "protocol": "openid-connect"
            }'
        echo "Client created: ${NEW_CLIENT_ID}"
    else
        echo "Client already exists: ${NEW_CLIENT_ID}"
    fi
}

# Get client secret
get_client_secret() {
    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${NEW_CLIENT_ID}" \
    -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')

    curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${CLIENT_UUID}/client-secret" \
    -H "Authorization: Bearer ${TOKEN}" | jq -r '.value'
}

# Create user if it doesn't exist
create_user() {
    if ! curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${NEW_USER}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -e '.[0]' > /dev/null; then
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
            "username": "'${NEW_USER}'",
            "enabled": true,
            "credentials": [{
                "type": "password",
                "value": "'${NEW_USER_PASSWORD}'",
                "temporary": false
            }]
            }'
        echo "User created: ${NEW_USER}"
    else
        echo "User already exists: ${NEW_USER}"
    fi
}

# Create role if it doesn't exist
create_role() {
    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${NEW_CLIENT_ID}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')

    if ! curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${CLIENT_UUID}/roles/${ROLE_NAME}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -e '.name' > /dev/null; then
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${CLIENT_UUID}/roles" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d '{
            "name": "'${ROLE_NAME}'"
            }'
        echo "Role created: ${ROLE_NAME}"
    else
        echo "Role already exists: ${ROLE_NAME}"
    fi
}

# Assign role to user if not already assigned
assign_role_to_user() {
    USER_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users?username=${NEW_USER}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')

    CLIENT_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients?clientId=${NEW_CLIENT_ID}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.[0].id')

    ROLE_UUID=$(curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/clients/${CLIENT_UUID}/roles" \
        -H "Authorization: Bearer ${TOKEN}" | jq -r '.[] | select(.name=="'${ROLE_NAME}'") | .id')

    if ! curl -s -X GET "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_UUID}/role-mappings/clients/${CLIENT_UUID}" \
        -H "Authorization: Bearer ${TOKEN}" | jq -e '.[] | select(.name=="'${ROLE_NAME}'")' > /dev/null; then
        curl -s -X POST "${KEYCLOAK_URL}/admin/realms/${REALM}/users/${USER_UUID}/role-mappings/clients/${CLIENT_UUID}" \
            -H "Authorization: Bearer ${TOKEN}" \
            -H "Content-Type: application/json" \
            -d '[{
            "id": "'${ROLE_UUID}'",
            "name": "'${ROLE_NAME}'"
            }]'
        echo "Role assigned to user: ${ROLE_NAME} -> ${NEW_USER}"
    else
        echo "Role already assigned to user: ${ROLE_NAME} -> ${NEW_USER}"
    fi
}


# Wait for Keycloak server to start
wait_for_keycloak() {
    echo "Waiting for Keycloak server to start..."
    start_time=$(date +%s)
    timeout=120

    while true; do
        if curl -s -o /dev/null -w "%{http_code}" "${KEYCLOAK_URL}/health" | grep -q "200"; then
            echo "Keycloak server is up and running."
            return 0
        fi

        current_time=$(date +%s)
        elapsed=$((current_time - start_time))

        if [ $elapsed -ge $timeout ]; then
            echo "Timeout: Keycloak server did not start within ${timeout} seconds."
            return 1
        fi

        echo "Still waiting for Keycloak server to start... (${elapsed} seconds elapsed)"
        sleep 5
    done
}


# Execute functions
if ! wait_for_keycloak; then
    echo "Failed to start Keycloak server. Exiting."
    exit 1
fi
create_client
KEYCLOAK_SECRET=$(get_client_secret)
echo "KEYCLOAK_SECRET=${KEYCLOAK_SECRET}" >> .env
create_user
create_role
assign_role_to_user

echo "Keycloak configuration completed."
