# Micromamba container
FROM mambaorg/micromamba:2.0.8 AS micromamba

# Final container
FROM ghcr.io/nextsimhub/nextsimdg-dev-env:latest

## build nextsimdg model
RUN git clone -b workshop_brown https://github.com/nextsimhub/nextsimdg.git /home/nextsimdg

WORKDIR /home/nextsimdg/build

ARG mpi=OFF
ARG xios=OFF
ARG jobs=1

RUN . /opt/spack-environment/activate.sh && cmake -DCMAKE_BUILD_TYPE=Release -DWITH_THREADS=ON -DENABLE_MPI=$mpi -DENABLE_XIOS=$xios -Dxios_DIR=/xios .. && make -j $jobs

##install libraries with mamba
USER root

ARG MAMBA_USER=mambauser
ARG MAMBA_USER_ID=57439
ARG MAMBA_USER_GID=57439
ENV MAMBA_USER=$MAMBA_USER
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV MAMBA_EXE="/bin/micromamba"

COPY --from=micromamba "$MAMBA_EXE" "$MAMBA_EXE"
COPY --from=micromamba /usr/local/bin/_activate_current_env.sh /usr/local/bin/_activate_current_env.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_shell.sh /usr/local/bin/_dockerfile_shell.sh
COPY --from=micromamba /usr/local/bin/_entrypoint.sh /usr/local/bin/_entrypoint.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_initialize_user_accounts.sh /usr/local/bin/_dockerfile_initialize_user_accounts.sh
COPY --from=micromamba /usr/local/bin/_dockerfile_setup_root_prefix.sh /usr/local/bin/_dockerfile_setup_root_prefix.sh

RUN /usr/local/bin/_dockerfile_initialize_user_accounts.sh && \
    /usr/local/bin/_dockerfile_setup_root_prefix.sh

USER $MAMBA_USER

SHELL ["/usr/local/bin/_dockerfile_shell.sh"]

ENTRYPOINT ["/usr/local/bin/_entrypoint.sh"]

COPY --chown=$MAMBA_USER:$MAMBA_USER environment.yml /tmp/environment.yml
RUN micromamba install -y -n base -f /tmp/environment.yml && \
    micromamba clean --all --yes

##install other utilities    
USER root

RUN apt-get -y -q update \
 && apt-get -y -q upgrade \
 && apt-get -y -q install \
	bash-completion \
	libnetcdf-c++4-dev \
	libboost-log1.74 \
	libboost-program-options1.74 \
	libeigen3-dev \
    mpich libmpich-dev \
	netcdf-bin \
        vim \
	wget \
 	cmake \
	git \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /home

EXPOSE 8888

CMD [ "jupyter", "lab", "--ip=0.0.0.0", "--no-browser", "--allow-root" ]
