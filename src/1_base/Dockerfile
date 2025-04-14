FROM eclipse-temurin:11.0.24_8-jdk

COPY ../commons/apt-installer.sh .
RUN ./apt-installer.sh
RUN rm apt-installer.sh

ENV NVM_DIR=/root/.nvm

RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash \
    && . "$NVM_DIR/nvm.sh" \
    && nvm install 22 \
    && nvm alias default 22 \
    # Create symlinks so `node`, `npm`, `npx` are available without loading nvm:
    && ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/node" /usr/local/bin/node \
    && ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/npm"  /usr/local/bin/npm \
    && ln -s "$NVM_DIR/versions/node/$(nvm current)/bin/npx"  /usr/local/bin/npx

# Test that Node & npm are found:
RUN node --version && npm --version
