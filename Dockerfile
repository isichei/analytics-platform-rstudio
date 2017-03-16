FROM rocker/r-ver:3.3.2

ENV USER=rstudio
# ENV USER_NAMESPACE

ARG PANDOC_TEMPLATES_VERSION
ENV PANDOC_TEMPLATES_VERSION ${PANDOC_TEMPLATES_VERSION:-1.18}

## Add RStudio binaries to PATH
ENV PATH /usr/lib/rstudio-server/bin:$PATH

## Download and install RStudio server & dependencies
## Attempts to get detect latest version, otherwise falls back to version given in $VER
## Symlink pandoc, pandoc-citeproc so they are available system-wide
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    file \
    git \
    libapparmor1 \
    libcurl4-openssl-dev \
    libedit2 \
    libssl-dev \
    lsb-release \
    psmisc \
    python-setuptools \
    sudo \
    wget \
    rrdtool \
    openssh-client \
    libxml2-dev \
  && wget -q https://download2.rstudio.org/rstudio-server-pro-1.0.136-amd64.deb \
  && dpkg -i rstudio-server-pro-1.0.136-amd64.deb \
  && rm rstudio-server-pro-*-amd64.deb \
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc /usr/local/bin \
  && ln -s /usr/lib/rstudio-server/bin/pandoc/pandoc-citeproc /usr/local/bin \
  && wget https://github.com/jgm/pandoc-templates/archive/${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && mkdir -p /opt/pandoc/templates && tar zxf ${PANDOC_TEMPLATES_VERSION}.tar.gz \
  && cp -r pandoc-templates*/* /opt/pandoc/templates && rm -rf pandoc-templates* \
  && mkdir /root/.pandoc && ln -s /opt/pandoc/templates /root/.pandoc/templates \
  && mkdir -p /etc/R \
  && echo '\n\
    \n .libPaths("~/R/library") \
    \n# Configure httr to perform out-of-band authentication if HTTR_LOCALHOST \
    \n# is not set since a redirect to localhost may not work depending upon \
    \n# where this Docker container is running. \
    \nif(is.na(Sys.getenv("HTTR_LOCALHOST", unset=NA))) { \
    \n  options(httr_oob_default = TRUE) \
    \n}' >> /usr/local/lib/R/etc/Rprofile.site \
  && echo "PATH=\"${PATH}\"" >> /usr/local/lib/R/etc/Renviron \
  && echo "r-libs-user=~/R/library" >> /etc/rstudio/rsession.conf \
  && git config --system credential.helper 'cache --timeout=3600' \
  && git config --system push.default simple

# TeX Distribution: Used for PDF generation
RUN apt-get install -y texinfo texlive texlive-latex-extra

# APT Cleanup
RUN apt-get clean && rm -rf /var/lib/apt/lists/

# R Packages
## Cloudyr
RUN R -e "install.packages(c('httr', 'xml2', 'base64enc', 'digest', 'curl', 'aws.signature', 'aws.s3'))"
RUN R -e "install.packages('aws.s3', repos = c('cloudyr' = 'http://cloudyr.github.io/drat'))"
## Markdown
RUN R -e "install.packages(c('evaluate', 'digest', 'formatR', 'highr', 'markdown', 'stringr', 'yaml', 'Rcpp', 'htmltools', 'caTools', 'bitops', 'knitr', 'jsonlite', 'base64enc', 'rprojroot', 'rmarkdown'))"
## Readr
RUN R -e "install.packages('readr')"
## Shiny
RUN R -e "install.packages('shiny')"

RUN echo "server-access-log=1" >> /etc/rstudio/rserver.conf
RUN echo "server-project-sharing=0" >> /etc/rstudio/rserver.conf
RUN echo "server-health-check-enabled=1" >> /etc/rstudio/rserver.conf
RUN echo "auth-proxy=1" >> /etc/rstudio/rserver.conf

COPY userconf.sh /etc/cont-init.d/conf

COPY start.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 8787

CMD ["/usr/local/bin/start.sh"]
