# syntax=docker/dockerfile:experimental

ARG BASE=debian:11
FROM scratch AS packages
COPY offline/code-server*.deb /tmp/

FROM $BASE

RUN apt-get update \
  && apt-get install -y \
    curl \
    dumb-init \
    zsh \
    htop \
    locales \
    man \
    nano \
    git \
    git-lfs \
    openjdk-17-jdk \
    procps \
    openssh-client \
    sudo \
    vim.tiny \
    lsb-release \
  && git lfs install \
  && rm -rf /var/lib/apt/lists/*

# https://wiki.debian.org/Locale#Manually
RUN sed -i "s/# en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen \
  && locale-gen
ENV LANG=en_US.UTF-8

RUN adduser --gecos '' --disabled-password coder \
  && echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

RUN ARCH="$(dpkg --print-architecture)" \
  && curl -fsSL "https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-$ARCH.tar.gz" | tar -C /usr/local/bin -xzf - \
  && chown root:root /usr/local/bin/fixuid \
  && chmod 4755 /usr/local/bin/fixuid \
  && mkdir -p /etc/fixuid \
  && printf "user: coder\ngroup: coder\n" > /etc/fixuid/config.yml

COPY entrypoint.sh /usr/bin/entrypoint.sh
RUN --mount=from=packages,src=/tmp,dst=/tmp/packages dpkg -i /tmp/packages/code-server*$(dpkg --print-architecture).deb

# Allow users to have scripts run on container startup to prepare workspace.
# https://github.com/coder/code-server/issues/5177
ENV ENTRYPOINTD=${HOME}/entrypoint.d



ARG CODE_BUILTIN_EXTENSIONS_DIR=/tmp/extensions


EXPOSE 8080
# This way, if someone sets $DOCKER_USER, docker-exec will still work as
# the uid will remain the same. note: only relevant if -u isn't passed to
# docker-run..local/share/code-server/User
COPY skel/.local/share/code-server/User /home/coder/.local/share/code-server/User
COPY skel/.p10k.zsh /home/coder/
COPY vscode-cutomisation  /usr/lib/code-server/src/browser/media
RUN chmod 777 /home/coder/.local/share/code-server/User/*.json
RUN chown coder:coder /home/coder/.local/share/code-server/User/*.json
RUN chown coder:coder /home/coder/.local/share/code-server/User

  ## Include custom fonts
RUN sed -i 's|</head>|	<link rel="preload" href="{{BASE}}/_static/src/browser/media/fonts/MesloLGS-NF-Regular.woff2" as="font" type="font/woff2" crossorigin="anonymous">\n	</head>|g' /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html\
  && sed -i 's|</head>|	<link rel="preload" href="{{BASE}}/_static/src/browser/media/fonts/MesloLGS-NF-Italic.woff2" as="font" type="font/woff2" crossorigin="anonymous">\n	</head>|g'  /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html\
  && sed -i 's|</head>|	<link rel="preload" href="{{BASE}}/_static/src/browser/media/fonts/MesloLGS-NF-Bold.woff2" as="font" type="font/woff2" crossorigin="anonymous">\n	</head>|g' /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html\
  && sed -i 's|</head>|	<link rel="preload" href="{{BASE}}/_static/src/browser/media/fonts/MesloLGS-NF-Bold-Italic.woff2" as="font" type="font/woff2" crossorigin="anonymous">\n	</head>|g' /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html\
  && sed -i 's|</head>|	<link rel="stylesheet" type="text/css" href="{{BASE}}/_static/src/browser/media/css/fonts.css">\n	</head>|g'  /usr/lib/code-server/lib/vscode/out/vs/code/browser/workbench/workbench.html
  ## Install code-server extensions

  ## Install font MesloLGS NF
# RUN mkdir -p /usr/share/fonts/truetype/meslo \
#   && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Regular.ttf \
#   && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Bold.ttf \
#   && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Italic.ttf \
#   && curl -sL https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf -o /usr/share/fonts/truetype/meslo/MesloLGS\ NF\ Bold\ Italic.ttf \
#   && fc-cache -fv 
RUN chmod 777 /home/coder/.local/share/code-server/

USER 1000
ENV USER=coder
WORKDIR /home/coder
WORKDIR ${HOME}

COPY vscode-cutomisation/EliverLara.andromeda-1.7.1.vsix EliverLara.andromeda-1.7.1.vsix 
RUN code-server --install-extension EliverLara.andromeda-1.7.1.vsix






## Install Oh My Zsh with Powerlevel10k theme
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
  && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git .oh-my-zsh/custom/themes/powerlevel10k \
  && sed -i 's/ZSH="\/home\/jovyan\/.oh-my-zsh"/ZSH="$HOME\/.oh-my-zsh"/g' .zshrc \
  && sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/g' .zshrc \
  && echo "\n# set PATH so it includes user's private bin if it exists\nif [ -d \"\$HOME/bin\" -a \"\$SHLVL\" = 1 -a ! \"\$TERM_PROGRAM\" = \"vscode\" ] ; then\n    PATH=\"\$HOME/bin:\$PATH\"\nfi" >> .zshrc \
  && echo "\n# set PATH so it includes user's private bin if it exists\nif [ -d \"\$HOME/.local/bin\" -a \"\$SHLVL\" = 1 -a ! \"\$TERM_PROGRAM\" = \"vscode\" ] ; then\n    PATH=\"\$HOME/.local/bin:\$PATH\"\nfi" >> .zshrc \
  && echo "\n# Update last-activity timestamps while in screen/tmux session\nif [ ! -z \"\$TMUX\" -o ! -z \"\$STY\" ] ; then\n    busy &\nfi" >> .bashrc \
  && echo "\n# Update last-activity timestamps while in screen/tmux session\nif [ ! -z \"\$TMUX\" -o ! -z \"\$STY\" ] ; then\n    setopt nocheckjobs\n    busy &\nfi" >> .zshrc \
  && echo "\n# To customize prompt, run \`p10k configure\` or edit ~/.p10k.zsh." >> .zshrc \
  && echo "[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh" >> .zshrc 




ENTRYPOINT ["/usr/bin/entrypoint.sh", "--bind-addr", "0.0.0.0:8080", "--auth","none","."]