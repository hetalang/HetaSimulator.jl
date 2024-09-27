FROM julia:latest

ENV JULIA_DEPOT_PATH=/opt/julia \
    JULIA_PKGDIR=/opt/julia

ENV PKGS \
    gcc \
    libc-dev 
RUN apt-get update && \
    apt-get -y --no-install-recommends install $PKGS

RUN apt-get -y install rsync

# install npm and nodejs packages
RUN apt-get -y install npm
RUN apt-get -y install nodejs

# install R and R packages
RUN apt-get -y install r-base
RUN Rscript -e 'install.packages(c("lattice", "mrgsolve", "tidyverse"));'

# install and precompile HetaSimulator
RUN mkdir /opt/julia && julia -e 'using Pkg; Pkg.add(["HetaSimulator", "PackageCompiler", "Plots"]);'
RUN mkdir /opt/julia/sysimages && julia -e 'using HetaSimulator, Plots, PackageCompiler; create_sysimage(["HetaSimulator", "Plots"], sysimage_path="/opt/julia/sysimages/hetasimulator.so", include_transitive_dependencies=false, cpu_target="generic")'

CMD ["julia"]
