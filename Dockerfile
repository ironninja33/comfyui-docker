FROM runpod/comfyui-5090:latest

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential pkg-config python3-dev cython3 \
    git wget yasm nasm

# Build FFmpeg 7 from source
WORKDIR /tmp
RUN wget https://ffmpeg.org/releases/ffmpeg-7.0.tar.gz \
    && tar xvf ffmpeg-7.0.tar.gz \
    && cd ffmpeg-7.0 \
    && ./configure --prefix=/usr/local --disable-doc --disable-debug --enable-shared \
    && make -j$(nproc) \
    && make install

# Update shared library cache
RUN ldconfig

# Expose ports
# 8188: ComfyUI
# 7888: Infinite Image Browsing
# 8080: FileBrowser
EXPOSE 8188 7888 8080

# Setup startup script
COPY config.ini /config.ini
COPY models.json /models.json
COPY json_patch.py /json_patch.py
COPY set_default_image_browser_path.py /set_default_image_browser_path.py
COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
