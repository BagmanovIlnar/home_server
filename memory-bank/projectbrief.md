# Project Brief: Home Server (домашний сервер)

## Overview
Персональный домашний сервер, разворачиваемый через Docker Compose на отдельной машине/хосте. Центральное звено — домен **Active Directory (Samba AD DC)** для единой аутентификации Linux/Windows/macOS; поверх — файловое хранилище (Samba member домена), media-стек: qBittorrent + Radarr/Sonarr/Lidarr + Jellyfin, медиасервер Plex. Конфигурация декларативная, всё хранится в одном git-репозитории.

## Core Requirements
- **Active Directory (Samba AD DC)**: домен HOME.ARPA (DNS+Kerberos+LDAP), единые учётки для Linux/Windows/macOS
- Файловый сервер Samba (member домена): общая шара `home_share` (гостевой доступ) + персональные домашние каталоги доменных пользователей
- Управление пользователями и стеком через Makefile (`make user-add` = samba-tool, `make up/logs/ps` = docker compose)
- торрент-клиент qBittorrent (BitTorrent, порт 8080) + автоматизация загрузок Radarr/Sonarr/Lidarr (фильмы/сериалы/музыка)
- Медиасервер Plex (порт 32400) с библиотекой, фильмами и сериалами
- Все данные (загрузки, медиа, конфиги) вынесены в `folders/` на хосте и переживают пересоздание контейнеров
- Автозапуск всех сервисов (`restart: always`)

## Goals
- Простой переносимый стек: `.env` + `docker compose up -d` поднимает весь сервер с доменом
- Данные и база домена отделены от контейнеров (volumes из `folders/`), переживают down/up
- Минимальное обслуживание, конфиги версонируются в git, секреты — только в `.env`

## Project Scope
**Входит:** AD DC + Samba member, qBittorrent + Radarr/Sonarr/Lidarr + Jellyfin, Plex; вспомогательные скрипты; заготовки (закомментированные) FTP (vsftpd) и Ace Stream.
**Не входит:** GPO/групповые политики (нет 445 у DC), reverse-proxy, HTTPS, мониторинг, бэкапы, интеграция AD с Plex/Jellyfin/media-стеком.
