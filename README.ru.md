# xray-manager

`xray-manager` — набор скриптов для управления Xray Core на Debian с несколькими режимами маршрутизации:

- `OFF` — Xray полностью выключен
- `SOCKS` — локальный SOCKS5-прокси на `127.0.0.1:10808`
- `SPLIT` — системный трафик через TUN с прямым доступом к DNS и Xray-серверу
- `FULL` — системный трафик через TUN, кроме обязательного bypass до Xray-сервера

Проект поддерживает:

- VLESS + Reality
- импорт `vless://...`
- генерацию runtime-конфигов
- проверку конфигов перед установкой
- backup перед заменой конфигурации
- восстановление последнего режима после загрузки
- восстановление маршрутов после смены сети через NetworkManager
- health-check и status-команды

## Requirements

Поддерживаемая система:

- Debian 13
- NetworkManager
- systemd
- Xray Core установлен в `/usr/local/bin/xray`

Необходимые пакеты:

    sudo apt install \
      iproute2 \
      network-manager \
      python3 \
      curl \
      sudo

Проверить Xray Core:

    /usr/local/bin/xray version

## Installation

Клонировать репозиторий:

    git clone https://github.com/xanderdi/xray-manager.git ~/xray-manager
    cd ~/xray-manager

Установить manager:

    sudo ./install.sh

Installer:

- проверяет зависимости;
- проверяет наличие Xray Core;
- создаёт необходимые каталоги;
- делает backup существующих файлов;
- устанавливает CLI-скрипты;
- устанавливает systemd restore unit;
- устанавливает NetworkManager dispatcher;
- отключает прямой autostart `xray.service`;
- включает `xray-manager-restore.service`;
- при первой установке создаёт безопасный режим `OFF`.

Проверить состояние:

    xray-status

Проверить connectivity:

    xray-check

## Import configuration

`xray-manager` поддерживает импорт из файла `connection.conf` и напрямую из `vless://` URI.

### Import from VLESS URI

Проверить и установить runtime-конфигурацию:

    sudo xray-import --install 'vless://...'

Перед установкой `xray-import`:

- генерирует `socks.json`, `split.json` и `full.json`;
- проверяет все три конфигурации;
- делает backup текущих runtime-файлов;
- обновляет `/etc/xray-manager/xray-manager.conf`;
- атомарно заменяет runtime-конфиги;
- восстанавливает текущий режим.

### Import from connection.conf

Пример структуры:

    configs/connection.conf.example

Установить конфигурацию:

    sudo xray-import --install /path/to/connection.conf

Сгенерировать конфиги без установки:

    xray-import /path/to/connection.conf /tmp/xray-test

## Modes

Переключение режима:

    sudo xray-mode off
    sudo xray-mode socks
    sudo xray-mode split
    sudo xray-mode full

Текущий режим сохраняется в:

    /var/lib/xray-manager/mode

После загрузки системы последний сохранённый режим восстанавливает:

    xray-manager-restore.service

### OFF

Полностью останавливает Xray и удаляет TUN/служебные маршруты.

### SOCKS

Запускает локальный SOCKS5:

    127.0.0.1:10808

Системная маршрутизация остаётся direct.

### SPLIT

Создаёт `xray0` и направляет IPv4 через TUN.

При этом manager сохраняет direct-доступ:

- к Xray-серверу;
- к DNS-серверам, которым нужен bypass;
- к локальным сетям через более специфичные маршруты.

### FULL

Создаёт `xray0` и направляет системный IPv4-трафик через TUN.

Direct bypass остаётся только для Xray-сервера, чтобы не возникала routing loop.

## Status and health check

Пассивный статус:

    xray-status

Показывает:

- текущий режим;
- состояние `xray.service`;
- SOCKS listener;
- состояние `xray0`;
- текущие IPv4-маршруты;
- маршрут до Xray-сервера.

Активная проверка connectivity:

    xray-check

Проверяет:

- direct-доступ в интернет;
- доступ через SOCKS;
- DNS-разрешение Xray-сервера;
- доступность Xray-сервера по TCP/443.

## Backups

Installer сохраняет предыдущие версии файлов в:

    /var/backups/xray-manager/

Импорт новой VLESS-конфигурации создаёт отдельный backup:

    /var/backups/xray-manager/import-YYYYMMDD-HHMMSS/

## Uninstall

Удалить только `xray-manager`, сохранив конфигурацию и состояние:

    sudo ./uninstall.sh

Удалить также `/etc/xray-manager` и `/var/lib/xray-manager`:

    sudo ./uninstall.sh --purge

Xray Core, `/usr/local/etc/xray` и `/etc/systemd/system/xray.service` uninstall-скрипт не удаляет.
