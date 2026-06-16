
FROM docker.io/library/ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates \
      perl \
      openjdk-17-jre \
      fontconfig \
      libxrender1 \
      libxtst6 \
      libxi6 \
      libxext6 \
      libfreetype6 \
      libnss3 \
      libstdc++6 \
		strace \
		sysstat \
 && rm -rf /var/lib/apt/lists/*

# Optional. Only if you want tools installed inside the image.
# COPY workbench-9.5.5.18 /usr/share/workbench-9.5.5.18
# RUN ln -s /usr/share/workbench-9.5.5.18 /usr/share/mrtools

ENV PATH=/usr/share/mrtools/bin:/usr/share/mrtools:/usr/bin:/bin
WORKDIR /work
