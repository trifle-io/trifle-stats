FROM debian:latest

ENV TZ=Europe/Bratislava
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# install ubuntu packages
RUN apt-get update -q \
 && apt-get install -y \
    build-essential \
    apt-transport-https \
    zsh \
    libpq-dev \
    git \
    curl \
    wget \
    unzip \
    gpg \
    gnupg2 \
    locales \
    autoconf \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libsqlite3-dev \
    tmux \
    htop \
    vim \
 && apt-get clean

#set the locale
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN wget https://github.com/robbyrussell/oh-my-zsh/raw/master/tools/install.sh -O - | zsh || true
RUN git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /root/powerlevel10k
COPY .zshrc /root/.zshrc
COPY .p10k.zsh /root/p10k.zsh

#install asdf
ENV ASDF_ROOT /root/.asdf
ENV PATH "${ASDF_ROOT}/bin:${ASDF_ROOT}/shims:$PATH"
RUN git clone https://github.com/asdf-vm/asdf.git ${ASDF_ROOT} --branch v0.10.0

RUN asdf plugin-add ruby https://github.com/asdf-vm/asdf-ruby.git

# install ruby
ENV RUBY_VERSION 3.0.0
RUN ASDF_RUBY_BUILD_VERSION=v20201225 asdf install ruby ${RUBY_VERSION} \
  && asdf global ruby ${RUBY_VERSION}

RUN gem install bundler

CMD ["zsh"]
