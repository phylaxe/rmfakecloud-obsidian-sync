FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      poppler-utils git openssh-client ca-certificates curl unzip \
    && rm -rf /var/lib/apt/lists/*

ARG RMAPI_VERSION=v0.0.32
RUN curl -sSL "https://github.com/ddvk/rmapi/releases/download/${RMAPI_VERSION}/rmapi-linux-amd64.tar.gz" -o /tmp/rmapi.tgz \
    && tar -xzf /tmp/rmapi.tgz -C /usr/local/bin rmapi \
    && rm /tmp/rmapi.tgz \
    && chmod +x /usr/local/bin/rmapi

RUN pip install --no-cache-dir \
      pdf2image \
      "git+https://github.com/EelcovanVeldhuizen/rmc.git@Excalidraw"

RUN curl -sSL https://raw.githubusercontent.com/EelcovanVeldhuizen/remarkable-obsidian-sync/main/main.py -o /app/main.py

COPY sync.sh /app/sync.sh
RUN chmod +x /app/sync.sh

WORKDIR /app
CMD ["sh", "-c", "echo 'sync container ready, trigger /app/sync.sh via Dokploy Schedule'; exec tail -f /dev/null"]
