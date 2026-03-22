FROM node:20-alpine

LABEL maintainer="TD Kubernetes"
LABEL description="Marp presentation server for Kubernetes course"

# Install Marp CLI
RUN npm install -g @marp-team/marp-cli@latest

# Create working directory
WORKDIR /slides

# Expose port for Marp server
EXPOSE 8080

# Default command: start Marp server
CMD ["marp", "--server", "--input-dir", ".", "--allow-local-files", ".", "--html"]
