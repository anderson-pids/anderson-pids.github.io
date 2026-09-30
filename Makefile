HUGO_IMAGE := ghcr.io/gohugoio/hugo:v0.167.0
DOCKER_RUN := docker run --rm -u $(shell id -u):$(shell id -g) -v "$(CURDIR)":/project $(HUGO_IMAGE)

.PHONY: init serve build new-post clean

## Baixa o tema (submódulo git). Rodar uma vez após o clone.
init:
	git submodule update --init --recursive

## Servidor local com rascunhos em http://localhost:1313 (Ctrl+C para parar)
serve:
	UID=$(shell id -u) GID=$(shell id -g) docker compose up blog

## Build de produção em ./public (mesmo comando da CI)
build:
	$(DOCKER_RUN) --minify

## Cria um post novo: make new-post name=meu-post
new-post:
	@test -n "$(name)" || (echo "uso: make new-post name=meu-post" && exit 1)
	$(DOCKER_RUN) new content post/$(name).md

clean:
	rm -rf public resources/_gen .hugo_build.lock
