FROM ubuntu:25.10 AS build

COPY prerequisites.list /tmp/prerequisites.list
COPY required.list /tmp/required.list

ENV AZURE_CORE_DISABLE_CONFIRM_PROMPT=1
ENV AZURE_CORE_ONLY_SHOW_ERRORS=1
ENV DEBIAN_FRONTEND=noninteractive
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV POWERSHELL_TELEMETRY_OPTOUT=1
ENV TF_IN_AUTOMATION=1
ENV TF_INPUT=0

LABEL authors="felsokning"
LABEL "com.azure.dev.pipeline.agent.handler.node.path"="/usr/local/bin/node"
LABEL "org.opencontainers.image.base.name"="ubuntu:24.04"
LABEL "org.opencontainers.image.vendor"="felsokning"

RUN apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get upgrade -y \
    && apt-get install dos2unix -y \
    && dos2unix /tmp/prerequisites.list \
    && dos2unix /tmp/required.list \
    # Install prerequisites
    && apt-get install -y --no-install-recommends $(cat /tmp/prerequisites.list) \
    # Add Aqua Security Repository
    && wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add - \
    && echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" > /etc/apt/sources.list.d/trivy.list \
    && curl -fsSL https://get.opentofu.org/opentofu.gpg | tee /usr/share/keyrings/opentofu.gpg \
    && curl -fsSL https://packages.opentofu.org/opentofu/tofu/gpgkey | gpg --no-tty --batch --dearmor -o /usr/share/keyrings/opentofu-repo.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/opentofu.gpg,/usr/share/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main\ndeb-src [signed-by=/usr/share/keyrings/opentofu.gpg,/usr/share/keyrings/opentofu-repo.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | tee /etc/apt/sources.list.d/opentofu.list \
    # Add GitHub CLI Repository
    && wget -nv -O- https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings//githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list \
    # Add HashiCorp Repository
    && wget --https-only --secure-protocol=TLSv1_2 -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list \
    # Add Helm Repository
    && curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list \
    # Add JFrog Repository
    && wget -qO - https://releases.jfrog.io/artifactory/api/v2/repositories/jfrog-debs/keyPairs/primary/public | gpg --dearmor -o /usr/share/keyrings/jfrog.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/jfrog.gpg] https://releases.jfrog.io/artifactory/jfrog-debs focal contrib" | tee /etc/apt/sources.list.d/jfrog.list \
    # Add Kubernetes Repository
    && curl -fsSL "https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key" | gpg --dearmor -o /usr/share/keyrings/kubernetes-apt-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list \
    # Add Microsoft Repository
    && wget --https-only --secure-protocol=TLSv1_2 https://packages.microsoft.com/config/ubuntu/$(lsb_release -r -s)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm -f packages-microsoft-prod.deb \
    && echo "deb [arch=$(dpkg --print-architecture)] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/azure-cli.list \
    && wget --https-only --secure-protocol=TLSv1_2 -q https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add - \
    # Add NodeJS Repository
    && wget --quiet --secure-protocol=TLSv1_2 --https-only -O - https://deb.nodesource.com/setup_25.x | bash \
    # Add Octopus Repository
    && curl -fsSL https://apt.octopus.com/public.key | gpg --dearmor -o /usr/share/keyrings/octopus.gpg \
    && chmod a+r /usr/share/keyrings/octopus.gpg \
    && echo "deb [arch="$(dpkg --print-architecture)" signed-by=/usr/share/keyrings/octopus.gpg] https://apt.octopus.com/ stable main" | tee /etc/apt/sources.list.d/octopus.list \
    && apt-get update \
    && ACCEPT_EULA=Y apt-get install -y --no-install-recommends $(cat /tmp/required.list) \
    # Update npm
    && npm config set fund false \
    && npm install -g n \
    && n 25.1.0 \
    && npm install -g npm@11.6.2 \
    && npm install -g grunt grunt grunt-cli mocha \
    # Install autocomplete for terraform
    && terraform -install-autocomplete \
    # Configure Azure CLI
    && az config set core.collect_telemetry=false \
    && az config set core.login_experience_v2=off \
    && az extension add --name azure-devops --allow-preview true --yes \
    && az extension add --name azure-firewall --allow-preview true --yes \
    && az extension add --name containerapp --allow-preview true --yes \
    && az extension add --name functionapp --allow-preview true --yes \
    && az extension add --name log-analytics --allow-preview true --yes \
    && az extension add --name webapp --allow-preview true --yes \
    # Install PowerShell Modules
    && pwsh -c 'Install-Module -Name Az -AllowClobber -Scope AllUsers -Verbose -Force' \
    && pwsh -c 'Install-Module -Name Az.OperationalInsights -AllowClobber -Scope AllUsers -Verbose -Force' \
    && pwsh -c 'Install-Module -Name Pester -AllowClobber -Scope AllUsers -Verbose -Force' \
    && pwsh -c 'Install-Module -Name PowerShellGet -AllowClobber -Scope AllUsers -Verbose -Force' \
    && pwsh -c 'Install-Module -Name powershell-yaml -AllowClobber -Scope AllUsers -Verbose -Force' \
    && pwsh -c 'Enable-AzureRmAlias -Scope LocalMachine -Verbose' \
    # Cleanup
    && apt-get clean
