UID=$(shell id -u)
GID=$(shell id -g)

.PHONY: pull
pull:
	@docker-compose pull hugo

# .PHONY: build
# build:
# 	@docker-compose build --build-arg USER_ID=${UID} --build-arg GROUP_ID=${GID}

# .PHONY: build-no-cache
# build-no-cache:
# 	@docker-compose build --no-cache --build-arg USER_ID=${UID} --build-arg GROUP_ID=${GID}

.PHONY: down
down:
	@docker-compose down

.PHONY: up
up:
	@docker-compose up blog

.PHONY: up-silent
up-silent:
	@docker-compose up -d blog

.PHONY: stop
stop:
	@docker-compose stop blog

.PHONY: shell
shell:
	@docker-compose exec blog bash

.PHONY: run
run:
	@docker-compose run --rm -p 1313:1313 blog $(filter-out $@,$(MAKECMDGOALS))

.PHONY: exec
exec:
	@docker-compose exec blog hugo $(filter-out $@,$(MAKECMDGOALS))

# Scape rule to match with any task. Case to avoid arguments of rule run
# Ref. beta at https://stackoverflow.com/questions/6273608/how-to-pass-argument-to-makefile-from-command-line/6273809#6273809
%:
	@:
