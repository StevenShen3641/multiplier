ARG IMAGE=ubuntu:22.04
FROM --platform=linux/amd64 ${IMAGE} as builder
ENV INSTALL_DIR=/work/install
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
        python3.11 python3.11-dev \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
RUN mkdir src build

COPY . /work/src/multiplier
RUN cmake \
    -S '/work/src/multiplier' \
    -B '/work/build/multiplier' \
    -G Ninja \
    -DCMAKE_LINKER_TYPE=LLD \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$(which clang-18)" \
    -DCMAKE_CXX_COMPILER="$(which clang++-18)" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=TRUE

RUN cmake --build '/work/build/multiplier' --target install
RUN chmod +x /work/install/bin/*
ENV PATH="/work/install/bin:${PATH}"

FROM --platform=linux/amd64 ${IMAGE} as release
COPY --from=builder /work/install /work/install
