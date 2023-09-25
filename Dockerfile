# base image
FROM ubuntu:20.04

#input GitHub runner version argument
ARG RUNNER_VERSION=2.306.0

#2.301.1
ENV DEBIAN_FRONTEND=noninteractive

LABEL BaseImage="ubuntu:20.04"
LABEL RunnerVersion=${RUNNER_VERSION}

# update the base packages + add a non-sudo user
RUN apt-get update -y && apt-get upgrade -y && useradd -m docker

# install the packages and dependencies along with jq so we can parse JSON (add additional packages as necessary)
RUN apt-get update \
    && apt-get upgrade -y --no-install-recommends \
    && apt-get install -y --no-install-recommends \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    unzip \
    wget \
    vim \
    gnupg \
    iputils-ping \
    jq \
    libcurl4 \
    libicu66 \
    libssl1.0 \
    libunwind8 \
    lsb-release \
    netcat \
    build-essential \
    libssl-dev \
    libffi-dev \
    software-properties-common \
    python3 \ 
    python3-venv \
    python3-dev \
    python3-pip \
    # && wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb \
    # && dpkg -i packages-microsoft-prod.deb \
    # && apt-get update \
    # && apt-get install -y --no-install-recommends powershell \
    && curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \   
    && apt-get update 

RUN pip3 install PyJWT
RUN pip3 install pyjwt[crypto]

#Excluded: nodejs python3 python3-venv python3-dev python3-pip nodejs

# Download and Install Powershell.
# Here we are manually installing power v7.3.1
# to install latest version uncomment the 4 line block in apt-get install xxxxxx powershell
RUN wget -q https://github.com/PowerShell/PowerShell/releases/download/v7.3.1/powershell_7.3.1-1.deb_amd64.deb \
    && dpkg -i powershell_7.3.1-1.deb_amd64.deb \
    && apt-get install -f
    

# Installing the required modules
RUN pwsh -Command "Install-Module -Name 'Az' -Force -Scope 'AllUsers'" \
    && pwsh -Command "Install-Module -Name 'Pester' -Force -Scope 'AllUsers' -RequiredVersion 4.10.1" \
    && pwsh -Command "Install-Module -Name 'PSScriptAnalyzer' -Force -Scope 'AllUsers'" \
    && pwsh -Command "Install-Module -Name 'Microsoft.Graph.Groups' -Force -Scope 'AllUsers'" \
    && pwsh -Command "Install-Module -Name 'SqlServer' -Force -Scope 'AllUsers'"


# The default directory to which Powershell modules are imported
RUN chmod -R 777 /opt/microsoft/powershell/
RUN chmod -R 777 /usr/local/share/powershell/
RUN chmod -R 777 /usr/share

#cd into the user directory, download and unzip the github actions runner
RUN cd /home/docker && mkdir actions-runner && cd actions-runner \
    && curl -O -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz \
    && tar xzf ./actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# install some additional dependencies
RUN chown -R docker ~docker && /home/docker/actions-runner/bin/installdependencies.sh

#Installing node. We can also just nodejs in the dependencies, however, here we are taking control of the version and installing specific version
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash \
    && apt-get install nodejs

# Update and Upgrade Packages
RUN apt-get update && apt-get upgrade -y

# install npm
RUN npm install -g npm@9.1.2
# install npm specific version in node16 externals
RUN npm install --prefix /home/docker/actions-runner/externals/node16/lib npm@9.1.2

# iterate and upgrade node modules
RUN  cd /home/docker/actions-runner/externals  \
    && find . ! -path "*/node_modules/*"  -execdir npm update \;
#-name "package.json"

# install sqlpackage to allow sql package deployments
RUN wget -progress=bar:force -q -O sqlpackage.zip \
            https://aka.ms/sqlpackage-linux \
            && unzip -qq sqlpackage.zip -d /opt/sqlpackage \
            && chmod a+x /opt/sqlpackage/sqlpackage \
            && rm sqlpackage.zip

# add over the start.sh script
ADD start.sh start.sh

# make the script executable
RUN chmod +x start.sh

# add over the start.sh script
ADD generateJWT.py generateJWT.py

RUN chmod +x generateJWT.py

# set the user to "docker" so all subsequent commands are run as the docker user
USER docker

# set the entrypoint to the start.sh script
ENTRYPOINT ["./start.sh"]
