# minio-image

Immagine container di [MinIO](https://github.com/minio/minio) (server e client `mc`) compilata
dal sorgente upstream. Il codice di MinIO e `mc` resta quello del commit pinnato; si alzano solo le
dipendenze Go con correzioni di sicurezza (vedi Limiti).

```
ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z
```

## Perche' esiste

MinIO community non e' piu' distribuito in forma binaria:

| Canale | Stato |
|---|---|
| Docker Hub `minio/minio`, `minio/mc` | ritirati |
| Quay `quay.io/minio/minio`, `quay.io/minio/mc` | 401, anche sui tag gia' pubblicati |
| Binari `dl.min.io` | 410 Gone |
| Repository GitHub `minio/minio`, `minio/mc` | archiviati, sorgente e tag leggibili |

Questo repository compila una release pinnata e la pubblica su GHCR, cosi' chi ha installazioni
basate su quella release puo' continuare a scaricarla.

## Contenuto

| Componente | Release | Commit upstream |
|---|---|---|
| server `minio` | `RELEASE.2025-10-15T17-29-55Z` | [`9e49d5e7`](https://github.com/minio/minio/commit/9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a) |
| client `mc` | `RELEASE.2025-08-13T08-35-41Z` | [`7394ce0d`](https://github.com/minio/mc/commit/7394ce0dd2a80935aded936b09fa12cbb3cb8096) |

- Architetture: `linux/amd64`, `linux/arm64`.
- Compilatore Go 1.26.10, base `ubi9/ubi-micro:9.8`.
- Checkout per commit SHA: il build fallisce se il commit non corrisponde.
- Layout identico all'immagine upstream: base `ubi9/ubi-micro`, binari in `/usr/bin`, stesso
  `docker-entrypoint.sh`, licenze in `/licenses`.
- `minio --version` e `mc --version` riportano la release e il commit upstream.

## Uso

Server:

```yaml
services:
  minio:
    image: ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minio
      MINIO_ROOT_PASSWORD: change-me
    volumes:
      - minio_data:/data
```

Client (`mc` e' nella stessa immagine):

```bash
docker run --rm --entrypoint /bin/sh ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z \
  -c 'mc alias set s3 http://minio:9000 minio "$PASSWORD" && mc ls s3/'
```

## Build

Il workflow `.github/workflows/build.yml` compila su ogni PR e pubblica su `main` o a mano.
In locale:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t minio:local .
```

Per cambiare release si aggiornano `MINIO_RELEASE`/`MINIO_COMMIT` e `MC_RELEASE`/`MC_COMMIT` nel
`Dockerfile` e `MINIO_RELEASE` nel workflow.

## Limiti

Upstream non rilascia piu' correzioni per la community edition: il codice di MinIO e' congelato
all'ultima release (`RELEASE.2025-10-15T17-29-55Z`). Questo repository non modifica il codice di
MinIO e `mc`; prima della compilazione alza le dipendenze Go elencate in `GO_SECURITY_BUMPS` nel
`Dockerfile` (grpc, amqp091-go, x/crypto, x/net, x/text e altre) alle versioni con le correzioni
note, con un solo `go get` perche' la risoluzione congiunta non riabbassi un modulo gia' alzato.

Le vulnerabilita' del codice di MinIO pubblicate dopo l'archiviazione non hanno una versione
corretta e restano: chi usa l'immagine le copre con misure di rete (MinIO non esposto in
scrittura fuori dalla rete interna, OIDC e LDAP non configurati se non servono).

## Licenza

MinIO e `mc` sono distribuiti sotto [GNU AGPL v3](LICENSE); il testo della licenza e i `CREDITS`
upstream sono inclusi nell'immagine in `/licenses`. Il Dockerfile e il workflow di questo
repository sono distribuiti sotto la stessa licenza. MinIO e' un marchio di MinIO, Inc.; questo
repository non e' affiliato a MinIO, Inc.
