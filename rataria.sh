#!/bin/bash

ALVO="$1"
BASE_DIR=$(pwd)

echo "[RECON] Iniciando subdomain enum..."
echo "[subfinder] Criando diretorio para resultados..."
echo "[subfinder] Executando subfinder..."
mkdir "${BASE_DIR}/subfinder"
subfinder_dir="${BASE_DIR}/subfinder"
subfinder_output="${subfinder_dir}/subfinder_${ALVO}.txt"
subfinder -silent -d "$ALVO" --all -o "${subfinder_output}"

echo "[assetfinder] Criando diretorio para resultados..."
echo "[assetfinder] Executando assetfinder..."
mkdir "${BASE_DIR}/assetfinder"
assetfinder_dir="${BASE_DIR}/assetfinder"
assetfinder_output="${assetfinder_dir}/assetfinder_${ALVO}.txt"
echo "$ALVO" | assetfinder -subs-only >"${assetfinder_output}"

echo "[amass] Criando diretorio para resultados..."
echo "[amass] Executando amass..."
mkdir "${BASE_DIR}/amass"
amass_dir="${BASE_DIR}/amass"
amass_output="${amass_dir}/amass_${ALVO}.txt"
amass enum -d "$ALVO" -nocolor -silent | grep "$ALVO" >"${amass_output}"

echo "[crt.sh] Criando diretorio para resultados..."
echo "[crt.sh] Executando crt.sh..."
mkdir "${BASE_DIR}/crt.sh"
crt_sh_dir="${BASE_DIR}/crt.sh"
crt_sh_output="${crt_sh_dir}/crt.sh_${ALVO}.txt"
crt "$ALVO" >"${crt_sh_output}"

# -------------------------------------

echo "[RECON] Iniciando subdomain enum com DNS..."
echo "[INFO] Preparando arquivo com todos subs..."
cp "$subfinder_output" "${BASE_DIR}/all_subs.txt"
ALL_SUBS_FILE="${BASE_DIR}/all_subs.txt"
cat "$assetfinder_output" | anew -q "$ALL_SUBS_FILE"
cat "$amass_output" | anew -q "$ALL_SUBS_FILE"
cat "$crt_sh_output" | anew -q "$ALL_SUBS_FILE"

echo "[alterx] Criando diretorio para resultados..."
echo "[alterx] Executando alterx..."
mkdir "${BASE_DIR}/alterx"
alterx_dir="${BASE_DIR}/alterx"
alterx_output="${alterx_dir}/alterx_${ALVO}.txt"
cat "$ALL_SUBS_FILE" | alterx -silent -o "$alterx_output"

echo "[shuffledns] Criando diretorio para resultados..."
echo "[shuffledns] Executando shuffledns..."
mkdir "${BASE_DIR}/shuffledns"
shuffledns_dir="${BASE_DIR}/shuffledns"
shuffledns_output="${shuffledns_dir}/shuffledns_${ALVO}.txt"
wget -q https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt -O "$shuffledns_dir/resolvers.txt"
shuffledns -list "$alterx_output" -r "$shuffledns_dir/resolvers.txt" -mode resolve -silent -o "$shuffledns_output"

echo "[dnsx] Criando diretorio para resultados..."
echo "[dnsx] Executando dnsx..."
mkdir "${BASE_DIR}/dnsx"
dnsx_dir="${BASE_DIR}/dnsx"
dnsx_output="${dnsx_dir}/dnsx_${ALVO}.txt"
cat "$shuffledns_output" | dnsx -silent -o "$dnsx_output"
cp "$dnsx_output" "$BASE_DIR/alive_domains.txt"

echo "[RECON] Iniciando Port Scanning e Service Detection..."
echo "[naabu] Criando diretorio para resultados..."
echo "[naabu] Executando naabu..."
mkdir "${BASE_DIR}/naabu"
naabu_dir="${BASE_DIR}/naabu"
naabu_output="${naabu_dir}/naabu_${ALVO}.txt"
cat alive_domains.txt | naabu -silent -o "$naabu_output"

echo "[RECON] Iniciando busca por web services..."
echo "[httpx] Criando diretorio para resultados..."
echo "[httpx] Executando httpx..."
mkdir "${BASE_DIR}/httpx"
httpx_dir="${BASE_DIR}/httpx"
httpx_output="${httpx_dir}/httpx_${ALVO}.txt"

cat "$naabu_output" | httpx -title -sc -silent -oa -o "$httpx_output"
