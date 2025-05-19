dkrun() {
	if (( $# < 2 )); then
		echo "usage: $0 <base-image-name> <local-name>"
		return 1
	fi

	imagename=$1
	localname=$2

	echo "FROM $imagename

	RUN apt-get update \
	    && apt-get install -y zsh git tmux

	RUN git clone https://github.com/neovim/neovim.git && cd neovim \
		  && git checkout release-0.11 && make CMAKE_BUILD_TYPE=RelWithDebInfo \ 
		  && sudo make install && cd .. && rm -rf neovim

	RUN wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh \
		  && sh install.sh && rm install.sh

	RUN git clone --recursive https://github.com/charlifu/config-home.git \
		  && mv -f config-home/* /root/ && rm -rf config-home

	RUN chsh -s \$(which zsh)

	RUN git config --global user.name charlifu && \
	    git config --global user.email charlifu@amd.com

	" | docker build -t $localname -f - ~

	docker run \
		--rm \
		--device=/dev/kfd \
		--device=/dev/dri \
		--group-add video \
		--memory $(python3 -c "import os; mlim = int(0.8 * os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') / 10**9); print(f'{mlim}G')") \
		--cap-add=SYS_PTRACE --security-opt seccomp=unconfined --privileged \
		--shm-size=16g \
		--ulimit core=0:0 \
		-e "TERM=xterm-256color" \
		-v /data/models:/models \
		-v ~/workspace:/workspace \
		--name $localname \
		-it $localname \
		/bin/zsh
}

dk-vllm-dev() {
	base_image="rocm/vllm-dev:nightly"
	if (( $# > 0 )); then
		base_image=$1
	fi

	echo "FROM $base_image

	RUN apt-get update \
	    && apt-get install -y zsh git tmux

	RUN git clone https://github.com/neovim/neovim.git && cd neovim \
		  && git checkout release-0.11 && make CMAKE_BUILD_TYPE=RelWithDebInfo \ 
		  && sudo make install && cd .. && rm -rf neovim

	COPY .oh-my-zsh /root/.oh-my-zsh

	COPY .zshrc /root/

	RUN chsh -s \$(which zsh)

	RUN git config --global user.name charlifu && \
	    git config --global user.email charlifu@amd.com

	RUN python3 -m pip uninstall -y vllm

	" | docker build -t charlifu_vllm -f - ~

	docker run \
		--rm \
		--device=/dev/kfd \
		--device=/dev/dri \
		--group-add video \
		--memory $(python3 -c "import os; mlim = int(0.8 * os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') / 10**9); print(f'{mlim}G')") \
		--cap-add=SYS_PTRACE --security-opt seccomp=unconfined --privileged \
		--shm-size=16g \
		--ulimit core=0:0 \
		-e "TERM=xterm-256color" \
		-v /data/models:/models \
		-v ~/workspace:/workspace \
		--name "charlifu_vllm" \
		-it charlifu_vllm \
		/bin/zsh
}

dk-triton-dev() {

	base_image="rocm/dev-ubuntu-24.04:6.4-complete"
	torch_repo="https://github.com/pytorch/pytorch.git"
	torch_branch="v2.7.0"
	if (( $# > 0 )); then
		base_image=$1
	fi

	echo "FROM $base_image

	ENV PYTORCH_ROCM_ARCH=gfx942
	RUN rm /usr/lib/python3.*/EXTERNALLY-MANAGED

	RUN apt update \
	    && apt install -y zsh git clang curl sudo vim less \
		&& apt install -y software-properties-common python-is-python3 \

	RUN python3 -m pip install packaging 'cmake<4' ninja setuptools pybind11 Cython

	RUN git clone $torch_repo pytorch
	RUN cd pytorch && git checkout $torch_branch && \
    pip install -r requirements.txt && git submodule update --init --recursive \
    && python3 tools/amd_build/build_amd.py \
    && CMAKE_PREFIX_PATH=$(python3 -c 'import sys; print(sys.prefix)') python3 setup.py bdist_wheel --dist-dir=dist \
    && pip install dist/*.whl \
	&& cd .. && rm -rf pytorch

	RUN git config --global user.name charlifu && \
	    git config --global user.email charlifu@amd.com

	COPY .oh-my-zsh /root/.oh-my-zsh

	COPY .zshrc /root/

	RUN chsh -s \$(which zsh)
	" | docker build -t charlifu_trt -f - ~

	docker run \
		--rm \
		--device=/dev/kfd \
		--device=/dev/dri \
		--group-add video \
		--memory $(python3 -c "import os; mlim = int(0.8 * os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') / 10**9); print(f'{mlim}G')") \
		--cap-add=SYS_PTRACE --security-opt seccomp=unconfined --privileged \
		--shm-size=16g \
		--ulimit core=0:0 \
		-e "TERM=xterm-256color" \
		-v ~/workspace/trt:/workspace \
		--name charlifu_trt \
		-it charlifu_trt \
		/bin/zsh
}
