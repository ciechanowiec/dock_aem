FROM eclipse-temurin:11-jdk

RUN apt update
RUN apt install less -y && \
    apt install curl -y && \
    apt install htop -y && \
    apt install psmisc -y && \
    apt install jq -y && \
    apt install vim -y && \
    apt install tree -y && \
    apt install wget -y && \
    apt install ffmpeg -y
# ffmpeg is requried to generate video renditions
