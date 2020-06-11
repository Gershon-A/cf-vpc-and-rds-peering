FROM alpine:edge

# https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
ARG AWS_IAM_AUTH_VERSION_URL="https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/amd64/aws-iam-authenticator"

# Install aws-iam-authenticator (latest version)
RUN curl -LO ${AWS_IAM_AUTH_VERSION_URL} && \
    mv aws-iam-authenticator /usr/bin/aws-iam-authenticator && \
    chmod +x /usr/bin/aws-iam-authenticator

# Install awscli
RUN apk add --update --no-cache python3 && \
    python3 -m ensurepip && \
    pip3 install --upgrade pip && \
    pip3 install awscli

# Install jq
RUN apk add --update --no-cache jq

# Install ntpd service
# Here is some BUG: the container time is different than host. 
# This is make AWS credentials not to work
RUN apk add openntpd 
##ntpd -d -f /etc/ntpd.conf -s
RUN apk add --no-cache tzdata
ENV TZ Asia/Jerusalem


WORKDIR /apps