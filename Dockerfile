FROM debian:sid

RUN apt-get -y update && DEBIAN_FRONTEND=noninteractive apt-get -y install html2text curl

RUN curl --location "https://golang.org/dl/go1.18.linux-amd64.tar.gz" | tar -xzf - -C /usr/local/

ENV PATH="/usr/local/go/bin:/usr/local/gopkg/bin:${PATH}"

RUN GOPATH=/usr/local/gopkg go install github.com/ericchiang/pup@latest

RUN rm -rvf /usr/local/go
