FROM westonsteimel/debian:sid-slim as builder

LABEL version="w2019-07-17"
ENV ZAPROXY_VERSION="w2019-07-17"
ENV WEBSWING_VERSION="2.6.3"
RUN apt-get update && apt-get install -q -y --fix-missing \
    unzip \
    curl \
    wget \
    xmlstarlet \
    git

WORKDIR /zap

RUN curl -s https://raw.githubusercontent.com/zaproxy/zap-admin/master/ZapVersions.xml | xmlstarlet sel -t -v //url |grep -i weekly | wget --content-disposition -i - && \
    unzip *.zip && \
    rm *.zip && \
    cp -R ZAP*/* . &&  \
    rm -R ZAP*
    
RUN curl -s -L "https://bitbucket.org/meszarv/webswing/downloads/webswing-${WEBSWING_VERSION}.zip" > webswing.zip && \
    unzip webswing.zip && \
    rm webswing.zip && \
    mv webswing-* webswing && \
    # Remove Webswing demos
    rm -R webswing/demo/ && \
    # Accept ZAP license
    touch AcceptedLicense
    
RUN git clone --depth 1 --branch "${ZAPROXY_VERSION}" https://github.com/zaproxy/zaproxy.git /src 

FROM openjdk:8-jdk-slim

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && apt-get install -q -y --fix-missing \
	net-tools \
	python3-pip \
	xvfb \
	x11vnc && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip zapcli python-owasp-zap-v2.4

RUN useradd -d /home/zap -m -s /bin/bash zap
RUN echo zap:zap | chpasswd
RUN mkdir /zap && chown zap:zap /zap

WORKDIR /zap

RUN mkdir /home/zap/.vnc

#ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
ENV PATH $JAVA_HOME/bin:/zap/:$PATH
ENV ZAP_PATH /zap/zap.sh

# Default port for use with zapcli
ENV ZAP_PORT 8080
ENV HOME /home/zap/

COPY --from=builder /zap /zap
COPY --from=builder /src/docker/zap* /zap/
COPY --from=builder /src/docker/webswing.config /zap/webswing/
COPY --from=builder /src/docker/policies /home/zap/.ZAP_D/policies/
COPY --from=builder /src/docker/scripts /home/zap/.ZAP_D/scripts/
COPY --from=builder /src/docker/.xinitrc /home/zap/

RUN chown -R zap:zap /zap

USER zap

HEALTHCHECK --retries=5 --interval=5s CMD zap-cli status
