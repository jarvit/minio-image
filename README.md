# minio-image

Immagine container di [MinIO](https://github.com/minio/minio) (server e client `mc`) compilata
dal sorgente upstream, senza modifiche.

```
ghcr.io/jarvit/minio:RELEASE.2025-09-07T16-13-09Z
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
| server `minio` | `RELEASE.2025-09-07T16-13-09Z` | [`07c3a429`](https://github.com/minio/minio/commit/07c3a429bfed433e49018cb0f78a52145d4bedeb) |
| client `mc` | `RELEASE.2025-08-13T08-35-41Z` | [`7394ce0d`](https://github.com/minio/mc/commit/7394ce0dd2a80935aded936b09fa12cbb3cb8096) |

- Architetture: `linux/amd64`, `linux/arm64`.
- Checkout per commit SHA: il build fallisce se il commit non corrisponde.
- Layout identico all'immagine upstream: base `ubi9/ubi-micro`, binari in `/usr/bin`, stesso
  `docker-entrypoint.sh`, licenze in `/licenses`.
- `minio --version` e `mc --version` riportano la release e il commit upstream.

## Uso

Server:

```yaml
services:
  minio:
    image: ghcr.io/jarvit/minio:RELEASE.2025-09-07T16-13-09Z
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minio
      MINIO_ROOT_PASSWORD: change-me
    volumes:
      - minio_data:/data
```

Client (`mc` e' nella stessa immagine):

```bash
docker run --rm --entrypoint /bin/sh ghcr.io/jarvit/minio:RELEASE.2025-09-07T16-13-09Z \
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

Upstream non rilascia piu' correzioni per la community edition: la versione e' congelata. Questo
repository non applica patch.

## Licenza

MinIO e `mc` sono distribuiti sotto [GNU AGPL v3](LICENSE); il testo della licenza e i `CREDITS`
upstream sono inclusi nell'immagine in `/licenses`. Il Dockerfile e il workflow di questo
repository sono distribuiti sotto la stessa licenza. MinIO e' un marchio di MinIO, Inc.; questo
repository non e' affiliato a MinIO, Inc.
