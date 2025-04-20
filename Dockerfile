FROM --platform=linux/amd64 rocker/tidyverse:4.5.0

# Install system dependencies and Node.js in one layer
RUN apt-get update && \
    apt-get install -y \
        git \
        libudunits2-dev \
        libgdal-dev \
        libgeos-dev \
        libproj-dev \
        curl \
        ca-certificates && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g mapshaper && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install R packages
RUN install2.r -e knitr languageserver sf
