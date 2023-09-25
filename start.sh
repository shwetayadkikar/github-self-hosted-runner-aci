function getJWTToken {
    echo "Getting JWT token for runner..."
    # Generate the JWT token
    
    JWT_TOKEN=`python3 ./generateJWT.py "$GH_PRIVATE_KEY" "$GH_APP_ID" "$GH_APP_INSTALLATION_ID"`
    echo ${JWT_TOKEN}
}

function getRegistrationToken {
    getJWTToken
    # Get a short lived token to register the actions runner
    echo "Getting registration token for runner..."

    if [[ -z $SCOPE ]]; then
        error "Was not able to identify SCOPE for the token"
        exit 1
    fi

    if [[ ${SCOPE} == "enterprises" ]]; then
        URL_PATH="$(echo "${RUNNER_URL}" | grep / | cut -d/ -f5-)"
    else
        # Get the path to the organization or repository
        URL_PATH="$(echo "${RUNNER_URL}" | grep / | cut -d/ -f4-)"
    fi
    TOKEN_URL="https://api.github.com/${SCOPE}/${URL_PATH}/actions/runners/registration-token"
    echo "TOKEN_URL: ${TOKEN_URL}"
    echo "JWT_TOKEN: ${JWT_TOKEN}"
    TOKEN="$(curl -X POST -fsSL -H "Authorization: Bearer ${JWT_TOKEN}" ${TOKEN_URL} | jq -r .token)"

}

function getRemovalToken {
    getJWTToken
    # Get a short lived token to register the actions runner
    echo "Getting removal token for runner..."

    if [[ -z $SCOPE ]]; then
        error "Was not able to identify SCOPE for the token"
        exit 1
    fi

    if [[ ${SCOPE} == "enterprises" ]]; then
        URL_PATH="$(echo "${RUNNER_URL}" | grep / | cut -d/ -f5-)"
    else
        # Get the path to the organization or repository
        URL_PATH="$(echo "${RUNNER_URL}" | grep / | cut -d/ -f4-)"
    fi
    TOKEN_URL="https://api.github.com/${SCOPE}/${URL_PATH}/actions/runners/remove-token"
    echo "TOKEN_URL: ${TOKEN_URL}"
    echo "JWT_TOKEN: ${JWT_TOKEN}"
    REMOVE_TOKEN="$(curl -X POST -fsSL -H "Authorization: Bearer ${JWT_TOKEN}" ${TOKEN_URL} | jq -r .token)"

}

RUNNER_OPTIONS=""
SCOPE=""
TOKEN=""
REMOVE_TOKEN=""

if [[ -z $RUNNER_NAME ]]; then
    echo "Using hostname for Actions Runner Name."
    export RUNNER_NAME=${HOSTNAME}
fi

# We need to know what type of runner we are
if [[ -z "${RUNNER_ENTERPRISE_URL}" && -z "${RUNNER_ORGANIZATION_URL}" && -z "${RUNNER_REPOSITORY_URL}" ]]; then
    error "RUNNER_ENTERPRISE_URL, RUNNER_ORGANIZATION_URL or RUNNER_REPOSITORY_URL needs to be specified when registering an Actions runner"
    exit 1
fi

# Use priority of enterprise -> organization -> repoistory if more than one specified
if [[ -n ${RUNNER_ENTERPRISE_URL} ]]; then
    export RUNNER_URL=${RUNNER_ENTERPRISE_URL}
    SCOPE=enterprises
elif [[ -n ${RUNNER_ORGANIZATION_URL} ]]; then
    export RUNNER_URL=${RUNNER_ORGANIZATION_URL}
    SCOPE=orgs
elif [[ -n ${RUNNER_REPOSITORY_URL} ]]; then
    export RUNNER_URL=${RUNNER_REPOSITORY_URL}
    SCOPE=repos
fi

# If the user has provided any runner labels add them to the config options
if [[ -n ${RUNNER_LABELS} ]]; then
   echo "RUNNER_LABELS were sent in input"
    #RUNNER_OPTIONS="${RUNNER_OPTIONS} --labels ${RUNNER_LABELS}"
else    
   RUNNER_LABELS="MY-ORG-RUNNER"  
fi

# The runner group that the self-hosted runner will be registered with
GROUP=${RUNNER_GROUP:-"default"}

echo "Getting temporary access token for registering runner"
getRegistrationToken

RUNNER_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
RUNNER_NAME="${RUNNER_NAME}-${RUNNER_SUFFIX}"


echo "Suffix: ${RUNNER_SUFFIX} " 
echo "Running config script with runner name ${RUNNER_NAME} "

cd /home/docker/actions-runner

./config.sh --unattended \
    --url "${RUNNER_URL}" \
    --token ${TOKEN} \
    --name ${RUNNER_NAME} \
    --labels ${GROUP},${RUNNER_LABELS} \
    --runnergroup "ORG SELF_HOSTED ACI RUNNERS" \
    $RUNNER_OPTIONS

cleanup() {
    echo "Removing runner..."
    getRemovalToken
    ./config.sh remove --unattended --token ${REMOVE_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!
