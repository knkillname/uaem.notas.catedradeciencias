FROM mcr.microsoft.com/devcontainers/base:bookworm

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get -y install \
        build-essential \
        inkscape \
        python3-full \
        python3-matplotlib \
        python3-networkx \
        python3-numpy \
        python3-pandas \
        python3-pygments \
        python3-scipy \
        python3-sympy \
        texlive-full && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

USER vscode
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/install_manual.sh)"
