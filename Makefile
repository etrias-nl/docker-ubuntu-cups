MAKEFLAGS += --warn-undefined-variables --always-make
.DEFAULT_GOAL := _

IMAGE=$(shell docker run -i --rm mikefarah/yq '.env.DOCKER_IMAGE' < .github/workflows/publish.yaml)
IMAGE_TAG=${IMAGE}:$(shell git describe --tags)

exec_docker=docker run $(shell [ "$$CI" = true ] && echo "-t" || echo "-it") -u "$(shell id -u):$(shell id -g)" --rm -v "$(shell pwd):/app" -w /app

lint-shell-scripts:
	${exec_docker} koalaman/shellcheck --severity=error --format=gcc docker-entrypoint.sh docker-entrypoint.d/*
lint-yaml:
	${exec_docker} cytopia/yamllint .
lint-dockerfile:
	${exec_docker} hadolint/hadolint hadolint --ignore DL3008 Dockerfile
lint: lint-shell-scripts lint-yaml lint-dockerfile
release: lint
	git tag "$(shell docker run --rm alpine/semver semver -i patch "$(shell git describe --tags --abbrev=0)")"
	git push --tags
build: lint
	docker buildx build --load --tag "${IMAGE_TAG}" .
cli: clean build
	docker exec -it "$(shell docker run -it -d "${IMAGE_TAG}")" sh
clean:
	docker rm $(shell docker ps -aq -f "ancestor=${IMAGE_TAG}") --force || true
	docker rmi $(shell docker images -q "${IMAGE}") --force || true
