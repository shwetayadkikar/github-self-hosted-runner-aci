#!/usr/bin/env python3
import jwt
import time
import sys
import requests

# Get PEM key
if len(sys.argv) > 1:
    key = sys.argv[1]
else:
    key = input("Enter path of private PEM file: ")

# Get the App ID
if len(sys.argv) > 2:
    app_id = sys.argv[2]
else:
    app_id = input("Enter your APP ID: ")


# Get the Installation ID
if len(sys.argv) > 3:
    installation_id = sys.argv[3]
else:
    installation_id = input("Enter your Installation ID: ")

# Open PEM
# with open(pem, 'rb') as pem_file:

signing_key = key.strip().encode('utf-8')
payload = {
    # Issued at time
    'iat': int(time.time()),
    # JWT expiration time (10 minutes maximum)
    'exp': int(time.time()) + 600,
    # GitHub App's identifier
    'iss': app_id
}
# Create JWT
encoded_jwt = jwt.encode(payload, signing_key, algorithm="RS256")


url = 'https://api.github.com/app/installations/'+ installation_id +'/access_tokens'

token_header = "bearer "+encoded_jwt
#print(token_header)

headers = {'Content-Type': 'application/json',
           "Authorization": token_header
           }
data = ''
response = requests.post(url, headers=headers)
token=response.json()['token']
print(token)
sys.exit(0)
