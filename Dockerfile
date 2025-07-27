ARG IMAGE=ubuntu:22.04
FROM --platform=linux/amd64 ${IMAGE} as builder
ENV WORKSPACE_DIR=/work
ENV INSTALL_DIR=${WORKSPACE_DIR}/install
ENV BUILD_DIR=${WORKSPACE_DIR}/build
ENV SRC_DIR=${WORKSPACE_DIR}/src

ENV DEBIAN_FRONTEND=noninteractive

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN apt-get update \
    && apt-get install --no-install-recommends -y curl gnupg software-properties-common lsb-release apt-utils \
    && apt-get remove --purge --auto-remove cmake \
    && apt-get update \
    && apt-get clean all 

RUN curl -sSL https://apt.kitware.com/keys/kitware-archive-latest.asc | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/kitware.gpg \
    && apt-add-repository "deb https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 6AF7F09730B3F0A4 \
    && apt-get update \
    && apt-get install kitware-archive-keyring \
    && rm /etc/apt/trusted.gpg.d/kitware.gpg

RUN apt-get install software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get install -y python3.12 python3.12-dev python3.12-venv

RUN python3.12 -m venv "${WORKSPACE_DIR}/install"

RUN curl -sSL https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - \
    && echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main" | tee -a /etc/apt/sources.list \
    && echo "deb-src http://apt.llvm.org/jammy/ llvm-toolchain-jammy-18 main" | tee -a /etc/apt/sources.list \
    && add-apt-repository ppa:ubuntu-toolchain-r/test \
    && apt-get install --no-install-recommends -y \
        gpg zip unzip tar git \
        pkg-config ninja-build ccache cmake=3.30.* \
        cmake-data=3.30.* build-essential \
        doctest-dev \
        clang-18 lld-18 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.12 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
RUN mkdir -p "${BUILD_DIR}"
RUN mkdir -p "${SRC_DIR}"
RUN mkdir -p "${INSTALL_DIR}"

COPY . /work/src/multiplier

# Environment

RUN ln -sf "$(which ld.lld-18)" /usr/local/bin/ld.lld

RUN cmake \
    -S "${SRC_DIR}/multiplier" \
    -B "${BUILD_DIR}/multiplier" \
    -G Ninja \
    -DCMAKE_LINKER_TYPE=LLD \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$(which clang-18)" \
    -DCMAKE_CXX_COMPILER="$(which clang++-18)" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" 

RUN cmake --build "${BUILD_DIR}/multiplier" --target install
RUN chmod +x ${WORKSPACE_DIR}/install/bin/*
ENV PATH="${WORKSPACE_DIR}/install/bin:${PATH}"

FROM --platform=linux/amd64 ${IMAGE} as release
COPY --from=builder /work/install /work/install
