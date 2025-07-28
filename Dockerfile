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
    && apt-get install --no-install-recommends -y wget curl gnupg software-properties-common lsb-release apt-utils build-essential ninja-build graphviz xdot\
    && apt-get remove --purge --auto-remove cmake \
    && apt-get update \
    && apt-get clean all 

RUN apt-get install software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get install -y python3.12 python3.12-dev python3.12-venv

RUN curl -sSL https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor - | tee /etc/apt/trusted.gpg.d/llvm.gpg \
    && apt-add-repository "deb https://apt.llvm.org/$(lsb_release -cs)/ llvm-toolchain-$(lsb_release -cs)-18 main" \
    && apt-get install -y clang-18

RUN wget https://github.com/Kitware/CMake/releases/download/v3.30.6/cmake-3.30.6-linux-x86_64.sh -q -O /tmp/cmake-install.sh \
    && chmod u+x /tmp/cmake-install.sh \
    && mkdir /opt/cmake-3.30.6 \
    && /tmp/cmake-install.sh --skip-license --prefix=/opt/cmake-3.30.6 \
    && ln -s /opt/cmake-3.30.6/bin/* /usr/local/bin

WORKDIR /work
RUN mkdir -p "${BUILD_DIR}"
RUN mkdir -p "${SRC_DIR}"
RUN mkdir -p "${INSTALL_DIR}"

COPY . /work/src/multiplier

# Environment

RUN cmake \
    -S "${SRC_DIR}/multiplier" \
    -B "${BUILD_DIR}/multiplier" \
    -G Ninja \
    -DCMAKE_LINKER_TYPE=LLD \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="$(which clang-18)" \
    -DCMAKE_CXX_COMPILER="$(which clang++-18)" \
    -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
    -DCMAKE_EXE_LINKER_FLAGS="--ld-path=$(which ld.lld-18)" \
    -DCMAKE_MODULE_LINKER_FLAGS="--ld-path=$(which ld.lld-18)" \
    -DCMAKE_SHARED_LINKER_FLAGS="--ld-path=$(which ld.lld-18)" \
    -DCMAKE_INTERPROCEDURAL_OPTIMIZATION=TRUE \
    -DMX_USE_VENDORED_CLANG=OFF \
    -DMX_ENABLE_INSTALL=ON

RUN cmake --build "${BUILD_DIR}/multiplier" --target install
RUN chmod +x ${WORKSPACE_DIR}/install/bin/*
ENV PATH="${WORKSPACE_DIR}/install/bin:${PATH}"

FROM --platform=linux/amd64 ${IMAGE} as release
COPY --from=builder /work/install /work/install
