FROM eclipse-temurin:11.0.24_8-jdk

COPY ../commons/apt-installer.sh .
RUN ./apt-installer.sh
RUN rm apt-installer.sh

ENV NVM_DIR=/root/.nvm

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 22 \
    && nvm alias default 22 \
    # Ensure the target directory exists before creating symlinks
    && mkdir -p /usr/local/bin \
    # Create symlinks so node, npm, npx are available without loading nvm:
    && ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/node" /usr/local/bin/node \
    && ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/npm"  /usr/local/bin/npm \
    && ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/npx"  /usr/local/bin/npx

# Test that Node & npm are found via symlinks
RUN node --version && npm --version

# Install aem-cli and create its symlink
# Source nvm.sh again here to ensure `nvm current` resolves correctly for the symlink path
RUN . "$NVM_DIR/nvm.sh" && \
    npm install -g @adobe/aem-cli && \
    ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/aem" /usr/local/bin/aem && \
    touch /root/.gitconfig

# Test that the aem command is now found via its symlink
RUN echo "aem-cli version:" && aem --version

# Add NVM sourcing to the default bash profile so interactive shells work as expected
# This also helps if your entrypoint script runs commands as the root user via bash
RUN echo '\nexport NVM_DIR="$HOME/.nvm"' >> /root/.bashrc && \
    echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> /root/.bashrc && \
    echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> /root/.bashrc
