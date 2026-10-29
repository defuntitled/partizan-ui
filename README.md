# partizan-ui

Клиент partizan для Android на Flutter. Он подключается к серверу partizan по тому же
протоколу, что клиенты для Linux и OpenWrt, и пропускает трафик телефона через
зашифрованный туннель: QUIC, а при заблокированном UDP — TCP+TLS. Туннель — это Rust-ядро
из репозитория [partizan](https://github.com/defuntitled/partizan), подключённое в виде AAR. Интерфейс на Dart не
привязан к Android, чтобы позже переиспользовать его на десктопе.

## Возможности

- **Серверы:** несколько профилей; добавление по ссылке `partizan://…` или QR-коду с
  проверкой ссылки ядром; переименование, удаление, порядок.
- **Подключение:** одно нажатие на пластинку на главном экране; также плитка в шторке
  быстрых настроек (долгое нажатие открывает приложение) и виджет на домашнем экране.
- **Раздельное туннелирование по адресам и подсетям:** режимы «только список» и
  «всё, кроме»; общие правила или свои для каждого сервера; импорт и экспорт списка
  файлом. DNS всегда идёт через туннель.
- **Kill Switch:** если туннель упал сам, интернет остаётся заблокированным до нажатия
  «Отключить». Для защиты при неработающем приложении есть ссылка на системную
  блокировку Android («Постоянная VPN»).
- **Безопасность:** токен хранится только в Android Keystore, не попадает в базу, логи и
  резервные копии. На устройстве не открывается локальный прокси-порт.

## Как это работает

```mermaid
flowchart LR
    A[Приложения телефона] -->|IP-пакеты| B[VpnService, TUN]
    B -->|fd| C[Ядро partizan, Rust]
    C -->|QUIC или TCP+TLS| D[Сервер partizan]
    D --> E[Сайт или сервис]
```

Android отдаёт приложению интерфейс TUN. Ядро разбирает пакеты собственным стеком TCP/IP
(`smoltcp`) и отправляет соединения и датаграммы через туннель или напрямую — по правилам
раздельного туннелирования. Интерфейс на Flutter общается с Kotlin-частью через
платформенные каналы, Kotlin с ядром — через биндинги UniFFI.

## Требования

| Что | Версия |
| --- | --- |
| Android | 8.0 (API 26) и новее, только arm64-v8a |
| Flutter | 3.47.8 |
| JDK для сборки | с `javac` (например, JBR из Android Studio) |
| Android SDK и NDK | NDK нужен для сборки ядра |
| Репозиторий ядра | [partizan](https://github.com/defuntitled/partizan) рядом с этим (`../partizan`) |

## Сборка и запуск

```sh
# Ядро: собирает AAR в ../partizan и кладёт его в android/app/libs.
scripts/core-aar.sh

flutter pub get
flutter build apk --release --target-platform android-arm64

# Отладочная сборка прямо на подключённый по adb телефон (данные сохраняются).
scripts/install-device.sh [serial]
```

Сборке нужны `JAVA_HOME` и `ANDROID_HOME`, сборке ядра — ещё `ANDROID_NDK_HOME` и
`cargo-ndk` (подробности — в `../partizan/CLAUDE.md`).

## Подпись релиза

Релизный APK собирает пайплайн `Release` в репозитории
[partizan](https://github.com/defuntitled/partizan): он клонирует этот репозиторий
(`ui_ref`, по умолчанию `main`), собирает ядро и приложение с версией ядра и прикладывает
`partizan-<версия>-android-arm64.apk` к релизу.

APK подписывается постоянным ключом из секретов репозитория **partizan**. Без него сборка
останавливается: APK с отладочной подписью нельзя обновить следующим релизом.

1. Один раз создайте ключ и храните его вне репозитория. Если ключ потерян, установленные
   приложения больше не обновятся.

   ```sh
   keytool -genkeypair -v -keystore partizan-release.jks -alias partizan \
       -keyalg RSA -keysize 4096 -validity 10000
   base64 -w0 partizan-release.jks > partizan-release.jks.b64
   ```

2. В `partizan` → Settings → Secrets and variables → Actions добавьте:

   | Секрет | Значение |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | содержимое `partizan-release.jks.b64` |
   | `ANDROID_KEYSTORE_PASSWORD` | пароль хранилища |
   | `ANDROID_KEY_ALIAS` | `partizan` |
   | `ANDROID_KEY_PASSWORD` | пароль ключа |

Локально release-сборка подписывается тем же ключом, если заданы `PARTIZAN_KEYSTORE`
(путь к `.jks`), `PARTIZAN_KEYSTORE_PASSWORD`, `PARTIZAN_KEY_ALIAS` и `PARTIZAN_KEY_PASSWORD`;
без них — отладочным.

## Тесты

```sh
flutter analyze
flutter test                                  # модель, хранилище, экраны
(cd android && ./gradlew :app:testDebugUnitTest)   # Kotlin: маршруты, плитка, Kill Switch
flutter test integration_test -d <устройство> # на телефоне: мост к ядру, служба VPN
```

`flutter test integration_test` в конце удаляет приложение с устройства вместе с
сохранёнными серверами.

## Устройство проекта

| Каталог | Что внутри |
| --- | --- |
| `lib/core/` | Модель и интерфейсы, не зависящие от платформы |
| `lib/data/` | Профили в SQLite (`drift`) |
| `lib/platform/` | Мост к Android по платформенным каналам |
| `lib/state/` | Состояние (`riverpod`) |
| `lib/ui/` | Экраны, тема, виджеты |
| `android/app/src/main/kotlin/` | `VpnService`, плитка, виджет, хранилище секретов |
| `assets/` | Шрифты и изображения |
| `spec/` | Спецификация клиента и концепт интерфейса |

## Лицензия

[GNU AGPL v3.0](LICENSE), как и у ядра partizan.

В приложении используются ресурсы со своими лицензиями:

- шрифты Oswald и Inter — SIL Open Font License 1.1 (`assets/fonts/OFL.txt`);
- карта мира — Simplemaps, лицензия MIT (текст — в `assets/images/world.svg`).

Полный список лицензий библиотек есть в приложении: «Настройки → О приложении →
Лицензии».
