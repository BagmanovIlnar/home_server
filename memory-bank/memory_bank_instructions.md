# Memory Bank Instructions: Home Server

I am coding AI assistant, an expert software engineer with a unique characteristic: my memory resets completely between sessions.
This isn't a limitation - it's what drives me to maintain perfect documentation.
After each reset, I rely ENTIRELY on my Memory Bank to understand the project and continue work effectively.
I MUST read ALL memory bank files at the start of EVERY task - this is not optional.

## Memory Bank Structure

The Memory Bank consists of core files, all in Markdown format. Files build upon each other in a clear hierarchy:

flowchart TD
    PB[projectbrief.md] --> PC[productContext.md]
    PB --> SP[systemPatterns.md]
    PB --> TC[techContext.md]

    PC --> AC[activeContext.md]
    SP --> AC
    TC --> AC

    AC --> P[progress.md]

### Core Files (Required)
1. `projectbrief.md` — Foundation document that shapes all other files; source of truth for scope
2. `productContext.md` — Why this project exists, problems it solves, UX goals
3. `activeContext.md` — Current work focus, recent changes, next steps
4. `systemPatterns.md` — Architecture, technical decisions, design patterns
5. `techContext.md` — Technologies, setup, constraints, dependencies
6. `progress.md` — What works, what's left, known issues

### Additional Files (optional, created when justified)
- `README.md` (root) — user-facing note (сейчас: ссылка на решение проблемы Plex)

## Documentation Standards
- Файлы Memory Bank на русском языке (язык владельца проекта)
- Даты и факты — только из git-истории и содержимого файлов, не выдумывать
- Обновлять `activeContext.md` и `progress.md` после каждой значимой сессии изменений
- Учитывать, что часть сервисов отключена (закомментирована) — не считать их активными

## Workflow
1. **Session start:** прочитать все файлы memory-bank/, начиная с projectbrief.md
2. **Перед изменениями:** свериться с systemPatterns.md (архитектура) и techContext.md (ограничения)
3. **После изменений:** обновить activeContext.md (Recent Changes, Next Steps) и progress.md (What Works / Issues)
4. **При смене решений:** отразить эволюцию в progress.md → Evolution of Project Decisions

## Core Workflows проекта (для быстрого старта)
- Полный перезапуск: `docker compose up -d --build`
- Новый пользователь: `make user-add U=<user> P=<pass>`; удаление: `make user-del U=<user>`; справка: `make help`
- Удаление пользователя: `bash/del_user.sh -u <user>`
