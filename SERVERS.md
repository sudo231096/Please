# Scraplands — сетевые серверы

Настоящий выделенный сервер на Godot (ENet/UDP). Никаких ботов и фейкового онлайна:
число игроков в меню приходит с самого сервера, играть можно из любой страны.

## Что уже сделано в коде

| Часть | Файл |
|---|---|
| Конфигурация адресов/портов | `scripts/net_config.gd` (+ переопределение `user://servers.cfg`) |
| Сервер и клиент (единый слой) | `scripts/net.gd` |
| Меню выбора сервера | `scripts/server_browser.gd`, `scenes/Servers.tscn` |
| Отрисовка других игроков | `scripts/remote_players.gd` |
| Отдельный прогресс на сервер | `GameState.set_active_server()` → `user://player_data_N.cfg` |

Свойства:

- транспорт ENet поверх UDP — работает через интернет, не только localhost;
- сервер авторитетен: валидирует координаты, ведёт список игроков, кикает по таймауту (12 с);
- жёсткий лимит **85 игроков**, 86-й получает `cl_join_rejected` и не входит;
- HTTP-эндпоинт статуса на `порт+100`: `GET /status` → `{"server":1,"players":7,"max":85,"online":true}`;
- у каждого сервера собственное семя мира (`world_seed`) → отдельное состояние карты;
- автопереподключение раз в 3 с при обрыве, корректная обработка disconnect.

## Запуск сервера

```bash
# Server 1 на порту 27015 (статус на 27115)
godot --headless --path . -- --server --id=1 --port=27015
```

Пять серверов на одной машине — пять процессов с разными `--id` и `--port`:

```bash
for i in 1 2 3 4 5; do
  godot --headless --path . -- --server --id=$i --port=$((27014+i)) &
done
```

Нужно открыть в фаерволе: **UDP** `27015-27019` (игра) и **TCP** `27115-27119` (статус).

## Бесплатная инфраструктура: что реально подходит

Проверено на сентябрь 2026:

| Провайдер | Годится? | Почему |
|---|---|---|
| **Oracle Cloud Always Free** | **да, единственный полноценный** | 2 ARM OCPU + 12 ГБ RAM, 10 ТБ трафика, публичный IPv4, произвольные UDP-порты, работает 24/7 без засыпания. В июне 2026 лимит ARM урезали вдвое, но одного always-on инстанса хватает |
| Google Cloud e2-micro | частично | 1 ГБ RAM, свои UDP-порты есть, но всего **1 ГБ исходящего трафика в месяц** — на живой шутер не хватит |
| Render / Koyeb / Northflank | нет | только HTTP/TCP, произвольный UDP не пробрасывается, free-инстансы засыпают через 15 мин |
| Fly.io | нет | постоянного free-тарифа с 2024 года нет, только пробные 2 машиночаса |
| Railway / Heroku | нет | free-тариф закрыт, только кредиты |

**Вывод: Oracle Cloud Always Free.** Это единственный бесплатный вариант, где можно
держать UDP-сервер круглосуточно с публичным IP.

### Развёртывание на Oracle Cloud (бесплатно)

1. Зарегистрируйся на cloud.oracle.com (карта нужна только для верификации, списаний нет).
2. Compute → Create Instance → shape **VM.Standard.A1.Flex**, 2 OCPU / 12 GB, Ubuntu 24.04.
3. Networking → Security List → Ingress Rules: разреши `0.0.0.0/0` UDP `27015-27019` и TCP `27115-27119`.
4. На самой машине (Oracle по умолчанию всё режет iptables):

```bash
sudo iptables -I INPUT -p udp --dport 27015:27019 -j ACCEPT
sudo iptables -I INPUT -p tcp --dport 27115:27119 -j ACCEPT
sudo netfilter-persistent save
```

5. Ставим Godot headless и код:

```bash
sudo apt update && sudo apt install -y unzip wget
wget https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_linux.arm64.zip
unzip Godot_v4.7.1-stable_linux.arm64.zip && chmod +x Godot_v4.7.1-stable_linux.arm64
git clone https://github.com/sudo231096/Please.git scraplands
cd scraplands && ../Godot_v4.7.1-stable_linux.arm64 --headless --import
```

6. systemd-юнит на каждый сервер (`/etc/systemd/system/scrap@.service`):

```ini
[Unit]
Description=Scraplands server %i
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/scraplands
ExecStart=/home/ubuntu/Godot_v4.7.1-stable_linux.arm64 --headless --path /home/ubuntu/scraplands -- --server --id=%i --port=2701%i
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
for i in 1 2 3 4 5; do sudo systemctl enable --now scrap@$i; done
```

7. Пропиши публичный IP инстанса в `scripts/net_config.gd` (поле `host` у всех пяти),
   либо на телефоне создай `user://servers.cfg`:

```ini
[server1]
host="1.2.3.4"
port=27015
```

После этого меню SERVERS покажет `ONLINE` и настоящее число игроков.

## Честно об ограничениях бесплатного тарифа

Один бесплатный Oracle-инстанс (2 ARM ядра / 12 ГБ) физически не потянет
**5 × 85 = 425** одновременных игроков в 3D-выживалке: узкое место — CPU на
симуляцию мира и ~40-60 Кбит/с на игрока исходящего трафика.

Реалистично на бесплатном тарифе:

- все 5 серверов поднимаются и доступны из интернета;
- комфортно — примерно **10-20 игроков суммарно** на инстанс;
- лимит 85 стоит в коде и работает, но упрётся в CPU раньше, чем в лимит.

Что делать при росте:

- Oracle позволяет 4 бесплатных ARM-инстанса в рамках квоты — разнести серверы по машинам
  (адреса разные, в конфиге у каждого сервера свой `host` — переписывать сетевой код не надо);
- при переходе на платный VPS меняется **только** `host`/`port` в `scripts/net_config.gd`.

Архитектура к этому готова: серверная логика, клиент, выбор сервера, сохранения и
конфигурация адресов разделены по разным файлам.
