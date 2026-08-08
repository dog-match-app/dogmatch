.DEFAULT_GOAL := help
COMPOSE := docker compose
FLUTTER := $(shell command -v flutter 2>/dev/null || echo $(HOME)/development/flutter/bin/flutter)

.PHONY: help up down nuke logs ps api migrate seed studio test-backend lint-backend analyze-mobile test-mobile run-mobile

help: ## Lista os comandos disponíveis
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

up: ## Sobe a infra local (db, redis, minio)
	$(COMPOSE) up -d db redis minio minio-setup

down: ## Derruba os containers
	$(COMPOSE) down

nuke: ## Derruba containers e APAGA volumes (reset total)
	$(COMPOSE) down -v

logs: ## Segue os logs da infra
	$(COMPOSE) logs -f

ps: ## Status dos containers
	$(COMPOSE) ps

api: ## Roda a API em modo watch
	cd backend && npm run start:dev

migrate: ## Aplica migrations (dev)
	cd backend && npx prisma migrate dev

seed: ## Popula o banco com dados de demonstração
	cd backend && npx prisma db seed

studio: ## Abre o Prisma Studio
	cd backend && npx prisma studio

test-backend: ## Testes unitários da API
	cd backend && npm test

lint-backend: ## Lint da API
	cd backend && npm run lint

analyze-mobile: ## Análise estática do app
	cd mobile && $(FLUTTER) analyze

test-mobile: ## Testes do app
	cd mobile && $(FLUTTER) test

run-mobile: ## Roda o app no emulador Android
	cd mobile && $(FLUTTER) run --dart-define=API_BASE_URL=http://10.0.2.2:3000

IP ?= $(shell hostname -I | awk '{print $$1}')
APK := mobile/build/app/outputs/flutter-apk/app-release.apk
ADB := $(shell command -v adb 2>/dev/null || echo $(HOME)/Android/Sdk/platform-tools/adb)

apk: ## Gera APK release apontando p/ o IP local (make apk [IP=192.168.x.x])
	cd mobile && $(FLUTTER) build apk --release --dart-define=API_BASE_URL=http://$(IP):3000
	@echo "\nAPK: $(APK) (API em http://$(IP):3000)"

push-apk: ## Copia o APK p/ Download do celular via adb (instalação manual)
	$(ADB) push $(APK) /sdcard/Download/dogmatch.apk
	@echo "\nNo celular: Gerenciador de arquivos → Downloads → dogmatch.apk → Instalar"
