FROM ubuntu:18.04 AS build
RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get install -y wget
RUN cd /tmp && \
    wget https://dl.google.com/go/go1.14.2.linux-amd64.tar.gz && \
    tar -xf go1.14.2.linux-amd64.tar.gz && \
    mv go /usr/local
RUN mkdir -p /app/prebid-server/
WORKDIR /app/prebid-server/
ENV GOROOT=/usr/local/go
ENV PATH=$GOROOT/bin:$PATH
ENV GOPROXY="https://proxy.golang.org"
RUN apt-get update && \
    apt-get install -y git && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
ENV CGO_ENABLED 0
COPY ./ ./
RUN go mod vendor
RUN go mod tidy
ARG TEST="true"
RUN if [ "$TEST" != "false" ]; then ./validate.sh ; fi
RUN go build -mod=vendor .

FROM ubuntu:18.04 AS release
ARG configName="test.yml"
WORKDIR /usr/local/bin/
COPY --from=build /app/prebid-server/prebid-server .
COPY conf/pro.yml pbs.yml
COPY conf/test.yml pbs_test.yml
COPY conf/sg_pro.yml sg_pbs.yml
COPY conf/us_pro.yml us_pbs.yml
COPY static static/
COPY stored_requests/data stored_requests/data
RUN apt-get update && \
    apt-get install -y ca-certificates mtr && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EXPOSE 9100
EXPOSE 6060
ENTRYPOINT ["/usr/local/bin/prebid-server"]
CMD ["-v", "1", "-logtostderr"]