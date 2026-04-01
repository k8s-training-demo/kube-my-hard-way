FROM node:20-slim

LABEL maintainer="TD Kubernetes"
LABEL description="Marp presentation server for Kubernetes course"

# Install Chromium (requis par Marp pour l'export PDF/PPTX/image)
RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

ENV CHROME_PATH=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# Install Marp CLI
RUN npm install -g @marp-team/marp-cli@latest

# Create working directory
WORKDIR /slides

# Expose port for Marp server
EXPOSE 8080

# Default command: start Marp server
CMD ["marp", "--server", "--input-dir", ".", "--allow-local-files", ".", "--html"]
