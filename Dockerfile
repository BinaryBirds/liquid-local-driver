FROM swift:5.7.3-amazonlinux2
RUN yum install make -y

WORKDIR /app
