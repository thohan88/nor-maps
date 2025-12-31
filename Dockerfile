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
        ca-certificates \
        # Dependencies for Tippecanoe
        build-essential \
        libsqlite3-dev \
        zlib1g-dev && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g mapshaper && \
    # Build and install Tippecanoe
    git clone https://github.com/felt/tippecanoe.git && \
    cd tippecanoe && \
    make -j$(nproc) && \
    make install && \
    cd .. && \
    rm -rf tippecanoe && \
    # Cleanup
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN echo "options(repos = c(CRAN = 'https://packagemanager.rstudio.com/cran/__linux__/noble/2025-12-30'), download.file.method = 'libcurl')" >> /usr/local/lib/R/etc/Rprofile.site
RUN install2.r -e duckdb knitr languageserver pxweb sf
RUN R -e "install.packages(c('terra', 'pmtiles'), repos = c('https://rspatial.r-universe.dev', 'https://walkerke.r-universe.dev', 'https://cloud.r-project.org'))"
