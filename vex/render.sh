#!/bin/sh
# Produce il documento OpenVEX di un'immagine pubblicata a partire dal modello.
#
#   vex/render.sh <tag> <digest> [<digest>...]
#
# <digest> nella forma sha256:...: il digest dell'indice multi-architettura, quelli
# delle singole piattaforme e delle loro configurazioni (con cui Trivy identifica
# un'immagine caricata nel Docker locale). Ogni digest diventa un prodotto pkg:oci con il server
# MinIO (modulo Go github.com/minio/minio) come sottocomponente: lo stato "fixed" vale
# solo per le immagini con quei digest, non per gli altri tag del repository.
set -eu

tag=$1
shift
dir=$(dirname "$0")
repo=${VEX_REPOSITORY:-ghcr.io/jarvit/minio}
name=${repo##*/}

for d in "$@"; do
  case "$d" in
    (sha256:*) ;;
    (*) echo "digest non valido: $d" >&2; exit 1 ;;
  esac
done

products=$(for d in "$@"; do
  printf '{"@id":"pkg:oci/%s@%s?repository_url=%s","subcomponents":[{"@id":"pkg:golang/github.com/minio/minio"}]}\n' \
    "$name" "$d" "$repo"
done | jq -s .)

jq --arg id "https://github.com/jarvit/minio-image/vex/$tag" \
   --arg ts "${VEX_TIMESTAMP:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" \
   --argjson products "$products" \
   '."@id" = $id | .timestamp = $ts | .statements |= map(.products = $products)' \
   "$dir/minio.openvex.template.json"
