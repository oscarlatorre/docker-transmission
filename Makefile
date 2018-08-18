USER = oscarlatorre
IMAGE ?= transmission:2.94

GIT_COMMIT = $(strip $(shell git rev-parse --short HEAD))

default: build
release: build push

build: Dockerfile entrypoint.go
	docker build \
		--build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
		--build-arg VCS_URL=`git config --get remote.origin.url` \
		--build-arg VCS_REF=$(GIT_COMMIT) \
		--tag $(USER)/$(IMAGE) .

push:
	docker push $(USER)/$(IMAGE)