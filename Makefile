SHELL := /bin/bash
COMPOSE ?= docker compose
SERVICE ?= app

.DEFAULT_GOAL := help
.PHONY: help build up down restart logs ps shell artisan composer npm migrate fresh seed test queue-restart prune

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

build: ## Build the application image
	$(COMPOSE) build --pull $(SERVICE)

up: ## Start the stack in the background
	$(COMPOSE) up -d --remove-orphans

down: ## Stop the stack and remove containers
	$(COMPOSE) down

restart: ## Restart every service
	$(COMPOSE) restart

logs: ## Follow logs (make logs SERVICE=queue)
	$(COMPOSE) logs -f --tail=100 $(SERVICE)

ps: ## Show service state and health
	$(COMPOSE) ps

shell: ## Open a shell in the app container
	$(COMPOSE) exec $(SERVICE) sh

artisan: ## Run an artisan command (make artisan CMD="route:list")
	$(COMPOSE) exec $(SERVICE) php artisan $(CMD)

composer: ## Run composer (make composer CMD="require foo/bar")
	$(COMPOSE) exec $(SERVICE) composer $(CMD)

npm: ## Run npm (make npm CMD="run build")
	$(COMPOSE) exec $(SERVICE) npm $(CMD)

migrate: ## Run migrations
	$(COMPOSE) exec $(SERVICE) php artisan migrate --force

fresh: ## Drop and re-run all migrations with seed data
	$(COMPOSE) exec $(SERVICE) php artisan migrate:fresh --seed --force

seed: ## Run seeders
	$(COMPOSE) exec $(SERVICE) php artisan db:seed --force

test: ## Run the test suite
	$(COMPOSE) exec $(SERVICE) php artisan test

queue-restart: ## Gracefully restart queue workers after a deploy
	$(COMPOSE) exec $(SERVICE) php artisan queue:restart

prune: ## Remove unused images and build cache
	docker image prune -f
	docker builder prune -f
