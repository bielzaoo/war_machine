#!/bin/bash

ALVO="$1"
BASE_DIR=$(pwd)

echo "[RECON] Iniciando subdomain enum..."
echo "[subfinder] Criando diretorio para resultados..."
echo "[subfinder] Executando subfinder..."
mkdir subfinder
subfinder_dir="$(pwd)/subfinder"
subfinder_output="${subfinder_dir}/subfinder_${ALVO}.txt"
subfinder -silent -d "$ALVO" --all -o "${subfinder_dir}/${subfinder_output}"

echo "[assetfinder] Criando diretorio para resultados..."
echo "[assetfinder] Executando assetfinder..."
mkdir assetfinder
assetfinder_dir="$(pwd)/assetfinder"
assetfinder_output="${assetfinder_dir}/assetfinder_${ALVO}.txt"
echo "$ALVO" | assetfinder -subs-only >"${assetfinder_dir}/${assetfinder_output}"

echo "[amass] Criando diretorio para resultados..."
echo "[amass] Executando amass..."
mkdir amass
amass_dir="$(pwd)/amass"
amass_output="${amass_dir}/amass_${ALVO}.txt"
amass enum -d "$ALVO" -nocolor | grep "$ALVO" >"${amass_dir}/${amass_output}"

echo "[crt.sh] Criando diretorio para resultados..."
echo "[crt.sh] Executando crt.sh..."
mkdir crt.sh
crt_sh_dir="$(pwd)/crt_sh"
crt_sh_output="${crt_sh_dir}/crt.sh_${ALVO}.txt"
crt "$ALVO" >"${crt_sh_dir}/${crt_sh_output}"

# -------------------------------------

echo "[RECON] Iniciando subdomain enum com DNS..."
echo "[INFO] Preparando arquivo com todos subs..."
cp "$subfinder_output" "$BASE_DIR/all_subs.txt"
ALL_SUBS_FILE="$BASE_DIR/all_subs.txt"
cat "$assetfinder_output" | anew -q "$ALL_SUBS_FILE"
cat "$amass_output" | anew -q "$ALL_SUBS_FILE"
cat "$crt_sh_output" | anew -q "$ALL_SUBS_FILE"

echo "[alterx] Criando diretorio para resultados..."
echo "[alterx] Executando alterx..."
mkdir alterx
alterx_dir="$(pwd)/alterx"
alterx_output="${alterx_dir}/alterx_${ALVO}.txt"
cat "$ALL_SUBS_FILE" | alterx -o "$alterx_output"

echo "[shuffledns] Criando diretorio para resultados..."
echo "[shuffledns] Executando shuffledns..."
mkdir shuffledns
shuffledns_dir="$(pwd)/shuffledns"
shuffledns_output="${shuffledns_dir}/shuffledns_${ALVO}.txt"
wget https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt -O "$shuffledns_dir/resolvers.txt"
shuffledns -list "$alterx_output" -r "$shuffledns_dir/resolvers.txt" -o "$shuffledns_output"

echo "[dnsx] Criando diretorio para resultados..."
echo "[dnsx] Executando dnsx..."
mkdir dnsx
dnsx_dir="$(pwd)/dnsx"
dnsx_output="${dnsx_dir}/dnsx_${ALVO}.txt"
cat "$shuffledns_output" | dnsx -o "$dnsx_output"
cp "$dnsx_output" "$BASE_DIR/alive_domains.txt"

echo "[RECON] Iniciando Port Scanning e Service Detection..."
echo "[naabu] Criando diretorio para resultados..."
echo "[naabu] Executando naabu..."
mkdir naabu
naabu_dir="$(pwd)/naabu"
naabu_output="${naabu_dir}/naabu_${ALVO}.txt"
cat alive_domains.txt | naabu -o "$naabu_output"

echo "[RECON] Iniciando busca por web services..."
echo "[httpx] Criando diretorio para resultados..."
echo "[httpx] Executando httpx..."
mkdir httpx
httpx_dir="$(pwd)/httpx"
httpx_output="${httpx_dir}/httpx_${ALVO}.txt"

cat "$naabu_output" | httpx -title -sc -silent -oa "$httpx_output"
