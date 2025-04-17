FROM --platform=linux/amd64 rocker/tidyverse:4.5.0

RUN apt-get update && \
    apt-get install -y \
    git \
    libudunits2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN install2.r -e sf
