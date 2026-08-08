# DogMatch — Mobile (Flutter)

App Flutter do DogMatch: donos criam perfis para seus cães, dão swipe em cães
próximos e, quando o like é mútuo, vira match com chat em tempo real.

> O contrato da API (endpoints, DTOs, eventos WebSocket) está em
> [`../ARCHITECTURE.md`](../ARCHITECTURE.md).

## Pré-requisitos

- Flutter (canal **stable**);
- Backend rodando (veja `../backend`): `http://localhost:3000`.

## Configuração da API

A URL da API é injetada em build time via `--dart-define=API_BASE_URL=...`
(padrão: `http://10.0.2.2:3000`, o localhost visto pelo emulador Android).

### Emulador Android

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

> Para o upload de fotos funcionar no emulador, o backend precisa assinar as
> URLs do MinIO com o host `10.0.2.2` (veja `S3_ENDPOINT`/`S3_PUBLIC_URL` no
> `backend/.env`, conforme o ARCHITECTURE.md §7.1).

### Dispositivo físico

Use o IP da sua máquina na rede local (celular e máquina na mesma rede) — passo a
passo completo na seção **[Rodando no seu celular](#-rodando-no-seu-celular-android)**:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.14:3000
```

### iOS Simulator

O simulador enxerga o `localhost` da máquina normalmente:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

## 📱 Rodando no seu celular (Android)

Guia completo do zero. iOS físico exige macOS + Xcode (impossível a partir de Linux);
o código iOS já está pronto para quando houver um Mac.

### 1. Instale o Android SDK (uma única vez)

`flutter analyze`/`test` funcionam sem ele, mas **buildar e instalar o app exige o
Android SDK**. O caminho mais simples é via Android Studio:

```bash
# opção A (snap):
sudo snap install android-studio --classic
# opção B: baixe em https://developer.android.com/studio e extraia

# Abra o Android Studio uma vez → o wizard instala SDK, platform-tools e build-tools
# (aceite o caminho padrão ~/Android/Sdk)
```

Depois, aceite as licenças e confira:

```bash
flutter doctor --android-licenses   # aceite tudo (y)
flutter doctor                      # "Android toolchain" deve ficar ✓
```

> Sem Android Studio (só CLI): instale `cmdline-tools` conforme
> https://docs.flutter.dev/get-started/install/linux/android e rode
> `sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0"`.

### 2. Prepare o celular

1. **Modo desenvolvedor**: Configurações → Sobre o telefone → toque **7×** em
   "Número da versão".
2. **Depuração USB**: Configurações → Sistema → Opções do desenvolvedor →
   ative **"Depuração USB"**.
3. **Regras udev (Linux)** para o adb enxergar o aparelho:
   ```bash
   sudo apt install android-sdk-platform-tools-common
   sudo udevadm control --reload-rules
   ```
4. Conecte o cabo USB (modo "Transferência de arquivos" se perguntado) e **aceite o
   popup "Permitir depuração USB?"** no celular (marque "Sempre permitir").
5. Confira:
   ```bash
   flutter devices   # seu aparelho deve aparecer na lista
   ```

### 3. Aponte o app para a API da sua máquina

No celular, `localhost` é o próprio celular — use o **IP da máquina** na rede Wi-Fi
(celular e computador na **mesma rede**):

```bash
hostname -I | awk '{print $1}'   # ex.: 192.168.1.14 (pode mudar com o DHCP)
```

Se o firewall `ufw` estiver ativo, libere as portas da API e do MinIO:

```bash
sudo ufw allow 3000/tcp && sudo ufw allow 9000/tcp
```

**Para as fotos funcionarem no celular**, o MinIO também precisa ser acessado pelo
IP — edite `backend/.env` e reinicie a API:

```env
S3_ENDPOINT=http://192.168.1.14:9000
S3_PUBLIC_URL=http://192.168.1.14:9000/dogmatch-media
```

### 4. Rode

Com a infra de pé (`make up` na raiz) e a API rodando (`npm run start:dev` em
`backend/`):

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=http://192.168.1.14:3000
```

O primeiro build demora alguns minutos (download do Gradle e dependências Android);
os seguintes são rápidos e com hot reload (`r` no terminal).

### Sem cabo: depuração por Wi-Fi (Android 11+)

```bash
# No celular: Opções do desenvolvedor → "Depuração por Wi-Fi" → "Parear com código"
adb pair 192.168.1.20:XXXXX     # IP:porta de pareamento mostrados no celular
adb connect 192.168.1.20:YYYYY  # IP:porta de conexão
flutter run --dart-define=API_BASE_URL=http://192.168.1.14:3000
```

### Gerando um APK e instalando manualmente (Xiaomi/MIUI)

Alguns aparelhos — MIUI/HyperOS em especial — **bloqueiam `adb install`** (a opção
"Instalar via USB" exige conta Mi/chip). O caminho garantido: gerar o APK, copiar
para o storage e instalar pelo gerenciador de arquivos.

**1. Gere o APK release** — a URL da API fica **gravada no binário**, use o IP atual
da máquina:

```bash
make apk                    # da raiz do repo; detecta seu IP via hostname -I
make apk IP=192.168.1.14    # ou informe explicitamente
# equivalente direto:
# cd mobile && flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.14:3000
```

Saída: `mobile/build/app/outputs/flutter-apk/app-release.apk`.
APK menor (só ARM 64-bit, cobre os Xiaomi atuais): adicione `--split-per-abi` e use
o `app-arm64-v8a-release.apk`.

**2. Copie para o celular** (celular conectado e autorizado no adb):

```bash
make push-apk   # = adb push .../app-release.apk /sdcard/Download/dogmatch.apk
```

> Sem adb: conecte o cabo em modo **"Transferência de arquivos (MTP)"** e arraste o
> APK para a pasta `Download` do aparelho pelo gerenciador de arquivos do desktop.

**3. Instale no celular**: Gerenciador de arquivos → **Downloads** → toque em
`dogmatch.apk` → na primeira vez, permita **"Instalar apps desconhecidos"** para o
gerenciador de arquivos → Instalar. Se o MIUI exibir aviso de verificação/scan,
escolha **"Instalar mesmo assim"**.

**4. Atualizações**: repita `make apk && make push-apk` e instale por cima — a
assinatura é a mesma, não precisa desinstalar (dados do app são preservados).

Notas:

- Se o DHCP trocar o IP da máquina, o APK aponta para a API errada — **regere** o APK.
- A API precisa estar rodando (`make up` + `npm run start:dev` em `backend/`) com as
  portas 3000/9000 liberadas no firewall; teste no navegador do celular:
  `http://SEU_IP:3000/health`.
- O build release usa a **assinatura de debug** (padrão do template Flutter) — ok
  para testes; para publicar na loja, configure um keystore próprio e prefira
  `flutter build appbundle`.

### Problemas comuns

| Sintoma | Causa provável / solução |
|---|---|
| `flutter devices` vazio | Cabo só de carga → troque; modo USB "Transferência de arquivos"; `adb kill-server && adb devices`; popup de autorização não aceito |
| `adb: insufficient permissions` | Faltam as regras udev: `sudo apt install android-sdk-platform-tools-common` e reconecte o cabo |
| `Failed to find target with hash string 'android-37'` | O SDK 37 instala como `android-37.0` (versão minor); crie a variante: `cp -al $ANDROID_HOME/platforms/android-37.0 $ANDROID_HOME/platforms/android-37` e corrija `AndroidVersion.ApiLevel=37` no `source.properties` da cópia |
| App abre mas login falha | IP errado ou firewall — teste no navegador do celular: `http://SEU_IP:3000/health` |
| Fotos não carregam | `S3_ENDPOINT`/`S3_PUBLIC_URL` sem o IP (passo 3) ou porta 9000 bloqueada |
| "Android license status unknown" | `flutter doctor --android-licenses` |
| 1º build muito lento | Normal (Gradle baixando); os próximos usam cache |

## Gerar código (json_serializable + injectable)

Após alterar modelos (`*.g.dart`) ou registros de DI (`injection.config.dart`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

Em desenvolvimento contínuo:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

## Testes e análise estática

```bash
flutter analyze
flutter test
```

## Estrutura

```
lib/
├── main.dart          # bootstrap + DI + runApp
├── app/               # MaterialApp.router, tema M3, go_router, injeção
├── core/              # config, rede (Dio/Socket.IO), storage, erros, widgets
└── features/          # auth, profile, dogs, discovery, matches, chat
    └── <feature>/
        ├── data/        # models (json_serializable) + repositórios (impl)
        ├── domain/      # entities/enums + contratos de repositório
        └── presentation/ # blocs/cubits, páginas, widgets
```

## Notas

- Tokens ficam no storage seguro (Keychain/Keystore); o `AuthInterceptor`
  renova o access token automaticamente em 401 (uma única tentativa por vez).
- O chat usa Socket.IO (namespace `/chat`); se o socket cair, o envio usa o
  fallback REST automaticamente.
- `android:usesCleartextTraffic="true"` e `NSAllowsArbitraryLoads` estão
  habilitados **apenas para desenvolvimento** (API em `http://`); restrinja em
  produção.
