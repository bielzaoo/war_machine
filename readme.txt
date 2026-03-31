Tools =========
Subdomain:
- subfinder (included)
- assetfinder (included)
- amass (included)
- crt.sh (included)
- Chaos

Dir eum:
- ffuf 
- feroxbuster
- dirsearch
- gobuster

Subdomain/DNS:
- alterx (included)
- shuffledns (included)
- dnsx (included)
- amass (included)

Port Scan/Service Dectection:
- naabu (included)

Web service detection:
- httpx (included)

Crawling:
- katana (included)
- getjs (included)
- subjs (included)
- gau (included)
- hakcrawler (included)
- jsfinder 
- linkfinder

Vuln:
- dalfox (included)
- nuclei (included)
- sqlmap (included)

Wordlist:
- Seclist (included)

crt.sh ====================================================
curl -s "https://crt.sh/?q=%.example.com&output=json" | jq -r '.[].name_value' | sed 's/\\n/\n/g' | grep -vF '*.' | sort -u > 0_example.com_crt.sh.txt


Amass =================================================
amass enum -d example.com -nocolor -o 0_example.com_amass.txt



Subfinder ============================================================

subfinder -> configure file with API keys.
nano ~/.config/subfinder/provider-config.yaml
subfinder -d cladious.com -all -o cladious_subdomains.txt
subfinder -d example.com --all --recursive -o 0_example.com_subfinder.txt

============================================================

alterx, shuffledns -> permutation e Mutation: Achar subdomiios que pssam na ter SSL e nao ser encontrado passivamente.
nano ~/.config/alterx/permutation_v0.1.0.yaml
cat cladious_subdomains.txt | alterx -o alterx_domain_cladious.txt

- Resolvers para serem usados para o Shuffledns:
wget https://wordlists-cdn.assetnote.io/data/manual/best-dns-wordlist.txt
wget https://raw.githubusercontent.com/projectdiscovery/public-bugbounty-programs/main/resolvers.txt
shuffledns -list cladious_subdomains.txt -r resolvers.txt -o shuffledns_cladious.txt

============================================================

dnsx -> Para saber quais desses dominios resolvem, sao validos e nao sao fakes.
cat alterx_domain_cladious.txt | dnsx -o alive_domains.txt

============================================================

naabu -> Port Scanning e service dectection mais efetivamnte e mais rapida.
cat alive_domains.txt | naabu -o cladious-ports.txt

httpx ===========================================================

httpx ->  para achar servi�os Web.
cat cladious-ports.txt | httpx -title -sc -silent 
httpx -silent -sc -title -tech-detect < 1_subdomains_alive.txt > 1_subdomains_alive-info.txt


JS/Crawling ============================================================

From Live subdomains: ------------------------------------------------

katana -> Deep Scanning e Crawling (JS) se tiver feature de login nmo alvo, eu consigo fornecer um session cookie apra o katana e ir além do login.
katana -u academy.cladious.com -jc -jsl
katana -list subdomains_alive.txt -d 2 -jc -silent | grep -E '\.js([?#].*)?$' | sort -u > live_katana_js.txt
-d 2 -> Deep, no dois ele segue links.


subjs -> crawl html pages
cat subdomains_alive.txt | subjs | sort -u > live_subjs_js.txt

getjs -> similiar o subjs, mas as vezes um pouco mais agressivo que anterior.
cat subdomains_alive.txt | getJS | sort -u > live_getjs_js.txt
----------------------------------------------------------------------

From archived URLs --------------------------------------------------
GAU -> A dica éem cima da lista de TODOS os subdominios, n�o só os ativos.
gau --subs < subdomains.txt | grep -E '\.js([?#].*)?$' | sort -u > archive_gau_js.txt

waybackurls ->  mesma coisa que o gau.
waybackurls < subdomains.txt | grep -E '\.js([?#].*)?$' | sort -u > archive_wayback_js.txt

Para epgar referencias a outros arquivos JS que possam estar linkados aos achados:
cat archive_gau_js.txt archive_wayback_js.txt | subjs | sort -u > archive_subjs_js.txt
cat archive_gau_js.txt archive_wayback_js.txt | getJS | sort -u > archive_getjs_js.txt

Condensando em um unico arquiv retirando duplicados:
sort -u live_*js.txt archive_*js.txt > all_js_files.txt

Caso queira filtrar para um unico alvo:
sort -u live_*js.txt archive_*js.txt > all_js_files.txt

Para analise offilen, caso queira =-=-=-=-=--=---=-=-
mkdir -p js_files

# Clear the hash_map.txt
> js_files/hash_map.txt

# One containing hashed filenames, and another containing the hash-to-URL mapping.
while read -r url; do
    hash=$(echo "$url" | md5sum | cut -d' ' -f1)
    echo "$hash $url" >> js_files/hash_map.txt
    curl -skLf --compressed "$url" -o "js_files/${hash}.js"
done < all_js_files.txt

