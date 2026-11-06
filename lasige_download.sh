#!/bin/bash
# Download the datasets listed in datasets.txt to ~/datasets on LASIGE, on a compute
# node (CPU only). Re-submit to resume: finished files are kept, partial ones continue.
#   farm-run submit lasige_download.sh --cluster lasige
#   farm-run status --cluster lasige
# Log: ~/slurm_outputs/dl-datasets_<jobid>.txt
#SBATCH --job-name=dl-datasets
#SBATCH --output=/mnt/storage/admindi/home/jfarinha/slurm_outputs/%x_%j.txt
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=4gb
#SBATCH --time=1-00:00:00
#SBATCH --partition=compute
set -euo pipefail

# sbatch runs a spooled copy of this script, so locate the manifest via the submit dir.
MANIFEST="${MANIFEST:-${SLURM_SUBMIT_DIR:-$PWD}/datasets.txt}"
# Outside the synced repo: farm-run's rsync --delete would wipe anything kept in there.
DEST="${DATASETS_DIR:-$HOME/datasets}"
PARALLEL="${SLURM_CPUS_PER_TASK:-4}"

echo "[dl] host=$(hostname) job=${SLURM_JOB_ID:-local} dest=$DEST parallel=$PARALLEL start=$(date)"

[ -f "$MANIFEST" ] || { echo "[dl] ERROR: manifest not found: $MANIFEST" >&2; exit 1; }

# Each manifest line is "<name> <url>"; check them all before downloading anything.
entries=$(awk '
  /^[[:space:]]*(#|$)/ { next }
  NF != 2 || $1 !~ /^[A-Za-z0-9._-]+$/ || $1 ~ /^\.+$/ || $2 !~ /^(https?|ftp):\/\// {
    printf "[dl] ERROR: %s:%d: expected \"<name> <url>\": %s\n", FILENAME, FNR, $0 > "/dev/stderr"; bad = 1; next
  }
  { print $1, $2 }
  END { exit bad }
' "$MANIFEST") || exit 1
[ -n "$entries" ] || { echo "[dl] ERROR: no datasets listed in $MANIFEST" >&2; exit 1; }

mkdir -p "$DEST"
FAILED=$(mktemp)
trap 'rm -f "$FAILED"' EXIT
export DEST FAILED

download_one() {
  local name=$1 url=$2
  mkdir -p "$DEST/$name"
  echo "[dl] start $name: $url"
  if wget --continue --content-disposition --no-verbose --tries=10 --waitretry=30 \
          --timeout=60 --directory-prefix="$DEST/$name" "$url"; then
    echo "[dl] done  $name: $url"
  else
    echo "[dl] FAIL  $name: $url (wget exit $?)" >&2
    echo "$name $url" >> "$FAILED"
  fi
}
export -f download_one

printf '%s\n' "$entries" | xargs -P "$PARALLEL" -L 1 bash -c 'download_one "$1" "$2"' _

echo "[dl] finished=$(date)"
du -sh "$DEST"/*

if [ -s "$FAILED" ]; then
  echo "[dl] $(wc -l < "$FAILED") download(s) failed:" >&2
  cat "$FAILED" >&2
  exit 1
fi
