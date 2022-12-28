FROM ruby:2.6

ARG HOME_DIR=/opt/work

ENV TZ Asia/Tokyo
RUN apt-get update \
  && apt-get install -y apt-utils \
  && apt-get install -y tzdata \
  && apt-get install -y openssh-server \
  && rm -rf /var/lib/apt/lists/* \
  && echo "${TZ}" > /etc/timezone \
  && rm /etc/localtime \
  && ln -s /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
  && dpkg-reconfigure -f noninteractive tzdata

RUN mkdir /var/run/sshd

RUN echo "Subsystem netconf ${HOME_DIR}/bin/netconf" >> /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

RUN echo 'root:root' | chpasswd

RUN    mkdir ${HOME_DIR} \
    && echo 'export PATH=$HOME/bin:$PATH' > ${HOME_DIR}/.bashrc

WORKDIR ${HOME_DIR}

COPY docker-entrypoint.sh /bin
ENTRYPOINT [ "docker-entrypoint.sh" ]
