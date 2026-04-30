FROM debian:stable-slim

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    sudo \
    zsh \
    unzip \
    ca-certificates \
    lsb-release \
    gnupg \
    jq \
    ripgrep \
    vim \
    less \
    iputils-ping \
    dnsutils \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Terraform
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
       > /etc/apt/sources.list.d/hashicorp.list \
    && apt-get update && apt-get install -y terraform \
    && rm -rf /var/lib/apt/lists/*

# Bitwarden CLI
RUN BW_VERSION=$(curl -fsSL https://api.github.com/repos/bitwarden/clients/releases | \
      jq -r '[.[] | select(.tag_name | startswith("cli-v"))] | first | .tag_name | ltrimstr("cli-v")') \
    && curl -fsSL "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip" \
       -o /tmp/bw.zip \
    && unzip /tmp/bw.zip -d /usr/local/bin \
    && chmod +x /usr/local/bin/bw \
    && rm /tmp/bw.zip

# Create vscode user
RUN groupadd -g 1000 vscode \
    && useradd -m -u 1000 -g 1000 -s /bin/zsh -G sudo vscode \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER vscode
ENV HOME=/home/vscode

RUN mkdir -p "$HOME/.local/bin" \
    "$HOME/.zsh_history_dir"

# Install oh-my-zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Install oh-my-zsh plugins
RUN git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting \
    && git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search.git \
    ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-history-substring-search

COPY --chown=vscode:vscode .zshrc /home/vscode/.zshrc

RUN chown -R vscode:vscode "$HOME/.local" "$HOME/.zsh_history_dir" 2>/dev/null || true

ENV PATH="/home/vscode/.local/bin:$PATH"
WORKDIR /workspace
