# minio-image

Immagine container di [MinIO](https://github.com/minio/minio) (server e client `mc`) compilata
dal sorgente upstream, con le patch di sicurezza di [`patches/`](patches/) applicate al sorgente
del server e le dipendenze Go con correzioni di sicurezza alzate.

```
ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z-jarvit.1
```

Il tag `RELEASE.2025-10-15T17-29-55Z` (senza suffisso) resta pubblicato com'era: e' la release
upstream senza patch, esposta alle vulnerabilita' elencate sotto.

## Perche' esiste

MinIO community non e' piu' distribuito in forma binaria:

| Canale | Stato |
|---|---|
| Docker Hub `minio/minio`, `minio/mc` | ritirati |
| Quay `quay.io/minio/minio`, `quay.io/minio/mc` | 401, anche sui tag gia' pubblicati |
| Binari `dl.min.io` | 410 Gone |
| Repository GitHub `minio/minio`, `minio/mc` | archiviati, sorgente e tag leggibili |

Le correzioni delle vulnerabilita' pubblicate dopo l'archiviazione esistono solo nel prodotto
commerciale MinIO AIStor, il cui codice non e' pubblico. Questo repository compila l'ultima
release community, la corregge con patch proprie e la pubblica su GHCR.

## Contenuto

| Componente | Release | Commit upstream |
|---|---|---|
| server `minio` | `RELEASE.2025-10-15T17-29-55Z` + patch `-jarvit.1` | [`9e49d5e7`](https://github.com/minio/minio/commit/9e49d5e7a648f00e26f2246f4dc28e6b07f8c84a) |
| client `mc` | `RELEASE.2025-08-13T08-35-41Z` | [`7394ce0d`](https://github.com/minio/mc/commit/7394ce0dd2a80935aded936b09fa12cbb3cb8096) |

- Architetture: `linux/amd64`, `linux/arm64`.
- Compilatore Go 1.26.10, base `ubi9/ubi-micro:9.8`.
- Checkout per commit SHA: il build fallisce se il commit non corrisponde.
- Layout identico all'immagine upstream: base `ubi9/ubi-micro`, binari in `/usr/bin`, stesso
  `docker-entrypoint.sh`, licenze in `/licenses`, patch applicate in `/licenses/patches`.
- `minio --version` e `mc --version` riportano la release e il commit upstream.

## Patch

| Patch | Vulnerabilita' | Cosa corregge |
|---|---|---|
| [`0001`](patches/0001-CVE-2026-39414-s3select-csv-record-limit.patch) | CVE-2026-39414, [GHSA-h749-fxx7-pwpg](https://github.com/advisories/GHSA-h749-fxx7-pwpg) | S3 Select legge una riga CSV fino a 1 MiB; oltre risponde `OverMaxRecordSize` invece di caricare in memoria l'intero input senza separatori. |
| [`0002`](patches/0002-CVE-2026-41145-unsigned-trailer-query-signature.patch) | CVE-2026-41145, [GHSA-hv4r-mvr4-25vw](https://github.com/advisories/GHSA-hv4r-mvr4-25vw) | Con `STREAMING-UNSIGNED-PAYLOAD-TRAILER` la firma si verifica per ogni sorgente di credenziali (intestazione `Authorization` e query `X-Amz-Credential`), non solo per l'intestazione. |
| [`0003`](patches/0003-CVE-2026-40344-extract-unsigned-trailer-signature.patch) | CVE-2026-40344, [GHSA-9c4q-hq6p-c237](https://github.com/advisories/GHSA-9c4q-hq6p-c237) | `PutObjectExtract` (snowball) verifica la firma anche con `STREAMING-UNSIGNED-PAYLOAD-TRAILER` e decodifica il corpo aws-chunked. |
| [`0004`](patches/0004-CVE-2026-34204-replication-headers-permission.patch) | CVE-2026-34204, [GHSA-3rh2-v3gr-35p9](https://github.com/advisories/GHSA-3rh2-v3gr-35p9) | Le intestazioni `X-Minio-Replication-*` diventano metadati interni solo nelle richieste di replica; ogni richiesta che si dichiara replica richiede `s3:ReplicateObject` (PutObject, CopyObject, NewMultipartUpload, PutObjectPart). |
| [`0005`](patches/0005-CVE-2026-33322-oidc-reject-hmac-id-token.patch) | CVE-2026-33322, [GHSA-5cx5-wh4m-82fh](https://github.com/advisories/GHSA-5cx5-wh4m-82fh) | Login OIDC: gli id_token firmati in HMAC con il client secret sono rifiutati; valgono solo firme RSA/ECDSA verificate con il JWKS del provider. |
| [`0006`](patches/0006-CVE-2026-33419-ldap-uniform-error-rate-limit.patch) | CVE-2026-33419, [GHSA-jv87-32hw-hh99](https://github.com/advisories/GHSA-jv87-32hw-hh99) | Login LDAP (STS, SFTP, FTP): stesso errore per utente inesistente e password errata; limite ai tentativi falliti per utente e indirizzo e per utente. |

Ogni patch e' un `git format-patch` con la causa nel messaggio e include i test Go che
riproducono l'attacco: falliscono sul sorgente upstream e passano con la patch.

Il `Dockerfile` applica le patch in ordine dopo il checkout per commit e prima di alzare le
dipendenze (`git apply --check` e poi `git apply`): se una patch non si applica il build
fallisce. Lo stage `test` esegue `go vet` e `go test` sui pacchetti toccati, con le dipendenze
gia' alzate; il workflow lo costruisce a ogni PR e a ogni build su `main`. In locale:

```bash
docker build --target test .
```

### Cambi di comportamento

- **OIDC**: un identity provider che firma gli id_token in HMAC (HS256/HS384/HS512) non e' piu'
  accettato. I provider piu' diffusi (Keycloak, Entra ID, Google, Okta, Auth0, Dex, Authentik)
  firmano in RS256 o ES256 per impostazione predefinita.
- **LDAP**: dopo 5 login falliti per lo stesso utente dallo stesso indirizzo, o 50 per lo stesso
  utente da qualunque indirizzo, nell'arco di 5 minuti dal primo errore, i tentativi successivi
  sono rifiutati senza interrogare il server LDAP fino alla scadenza della finestra (l'STS
  risponde `AccessDenied`). Un login riuscito azzera gli errori di quell'indirizzo. Variabili:

  | Variabile | Predefinito | Significato |
  |---|---|---|
  | `_MINIO_IDENTITY_LDAP_LOGIN_MAX_FAILURES` | `5` | errori per utente e indirizzo; `0` disattiva |
  | `_MINIO_IDENTITY_LDAP_LOGIN_MAX_FAILURES_PER_USER` | `50` | errori per utente su tutti gli indirizzi; `0` disattiva |
  | `_MINIO_IDENTITY_LDAP_LOGIN_FAILURE_WINDOW` | `5m` | finestra, durata Go |

  Il conteggio e' in memoria per ciascun nodo. L'indirizzo e' quello che MinIO attribuisce al
  client: se MinIO e' esposto senza un proxy che riscrive `X-Forwarded-For`, impostare
  `_MINIO_API_XFF_HEADER=off`, altrimenti il client sceglie il proprio indirizzo e resta solo il
  limite per utente.
- **Replica**: le credenziali del target di replica devono avere `s3:ReplicateObject`, come
  richiede gia' la documentazione di MinIO.

## Uso

Server:

```yaml
services:
  minio:
    image: ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z-jarvit.1
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minio
      MINIO_ROOT_PASSWORD: change-me
    volumes:
      - minio_data:/data
```

Client (`mc` e' nella stessa immagine):

```bash
docker run --rm --entrypoint /bin/sh ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z-jarvit.1 \
  -c 'mc alias set s3 http://minio:9000 minio "$PASSWORD" && mc ls s3/'
```

L'immagine legge i dati scritti dalla release `RELEASE.2025-10-15T17-29-55Z`: le patch non
cambiano il formato su disco.

## VEX e firma

Gli scanner che confrontano la versione del modulo Go `github.com/minio/minio` continuano a
segnalare le sei vulnerabilita', perche' la versione del modulo e' quella upstream. Ogni
immagine pubblicata porta un documento [OpenVEX](https://github.com/openvex/spec) firmato che
le dichiara `fixed`, con la patch indicata in `status_notes`:

- il modello e' [`vex/minio.openvex.template.json`](vex/minio.openvex.template.json);
  [`vex/render.sh`](vex/render.sh) lo compila con i digest dell'immagine (indice
  multi-architettura e singole piattaforme), cosi' lo stato `fixed` vale solo per quei digest e
  non per gli altri tag del repository;
- il workflow lo allega all'immagine con `cosign attest --type openvex`, firma keyless con
  l'identita' OIDC del workflow (nessuna chiave privata da custodire);
- [`vex/minio.openvex.json`](vex/minio.openvex.json) e' il documento dell'ultima immagine
  pubblicata.

Verifica della firma:

```bash
cosign verify-attestation --type openvex \
  --certificate-identity https://github.com/jarvit/minio-image/.github/workflows/build.yml@refs/heads/main \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z-jarvit.1 > /dev/null
```

Scansione con Trivy (0.75 o successivo), con il VEX scoperto dal registry o passato come file:

```bash
trivy image --vex oci --show-suppressed ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z-jarvit.1
trivy image --vex vex/minio.openvex.json --show-suppressed ghcr.io/jarvit/minio:RELEASE.2025-10-15T17-29-55Z-jarvit.1
```

Trivy non verifica la firma del VEX scoperto con `--vex oci`: la verifica e' il comando
`cosign verify-attestation` sopra.

## Build

Il workflow `.github/workflows/build.yml` esegue i test delle patch e compila su ogni PR; su
`main` o a mano pubblica il tag, se non esiste gia', e allega il VEX firmato. Un tag gia'
pubblicato non si sovrascrive; il VEX si allega dove manca anche a un tag esistente, quindi un
run fallito durante la firma si completa rieseguendo il workflow. In locale:

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t minio:local .
```

Per cambiare release si aggiornano `MINIO_RELEASE`/`MINIO_COMMIT`, `MC_RELEASE`/`MC_COMMIT` e
`IMAGE_TAG` nel `Dockerfile` e `MINIO_RELEASE`/`IMAGE_TAG` nel workflow, e si verifica che le
patch si applichino ancora.

## Nuova vulnerabilita'

1. Leggere l'avviso e il codice al commit pinnato; riprodurre con un test Go che fallisce.
2. Correggere alla causa nel sorgente, con il test nello stesso commit, ed esportare con
   `git format-patch` in `patches/NNNN-<CVE>-<descrizione>.patch` (numero successivo).
3. Aggiungere i pacchetti dei nuovi test allo stage `test` del `Dockerfile` e la vulnerabilita'
   a `vex/minio.openvex.template.json` e alla tabella delle patch.
4. Alzare la revisione di `IMAGE_TAG` (`-jarvit.N+1`) nel `Dockerfile` e nel workflow: il tag
   precedente non si sovrascrive.
5. Dopo la pubblicazione, aggiornare `vex/minio.openvex.json` con il documento allegato al
   build (artifact del workflow) e il digest nel README.

## Limiti

- Il codice di MinIO resta quello di `RELEASE.2025-10-15T17-29-55Z` con le sole patch di
  `patches/`: upstream non rilascia piu' correzioni per la community edition, e una
  vulnerabilita' nuova resta aperta finche' non entra una patch qui.
- Le patch correggono le cause descritte negli avvisi; non riproducono le correzioni di AIStor,
  il cui codice non e' pubblico, e possono differire nei dettagli (messaggi d'errore, limiti).
- Le dipendenze Go elencate in `GO_SECURITY_BUMPS` nel `Dockerfile` (grpc, amqp091-go, x/crypto,
  x/net, x/text e altre) si alzano alle versioni con le correzioni note, con un solo `go get`
  perche' la risoluzione congiunta non riabbassi un modulo gia' alzato.
- Il limite ai login LDAP e' per nodo e in memoria: si azzera al riavvio. Resta una differenza
  di tempo di risposta fra utente inesistente (nessun bind) e password errata, attenuata dal
  limite ai tentativi.

## Licenza

MinIO e `mc` sono distribuiti sotto [GNU AGPL v3](LICENSE); il testo della licenza e i `CREDITS`
upstream sono inclusi nell'immagine in `/licenses`. Il codice di MinIO contenuto nell'immagine
e' modificato: le modifiche sono le patch in [`patches/`](patches/), pubblicate in questo
repository e incluse nell'immagine in `/licenses/patches`; il sorgente corrispondente e' il
commit upstream indicato sopra con quelle patch applicate. Il Dockerfile, le patch e il workflow
di questo repository sono distribuiti sotto la stessa licenza. MinIO e' un marchio di MinIO,
Inc.; questo repository non e' affiliato a MinIO, Inc.
