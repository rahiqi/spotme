FROM ghcr.io/cirruslabs/flutter:3.22.2

WORKDIR /app

# Copy all project files
COPY . .

# Setup global Gradle mirror configuration
RUN mkdir -p /root/.gradle && cp init.gradle /root/.gradle/init.gradle

# Make the build script executable
RUN chmod +x build_apk.sh

# Define build arguments
ARG GIT_SHA=unknown
ARG TIMESTAMP=latest

ENV GIT_SHA=$GIT_SHA
ENV TIMESTAMP=$TIMESTAMP

# Run the build script
CMD ["./build_apk.sh"]
