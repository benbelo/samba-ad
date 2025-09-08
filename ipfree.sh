!/bin/bash

# Refonte du script ipfree par BB (v2 avec mktemp)
# à utiliser en prod uniquement, peut casser si les outils changent

# Check les arguments
subnet="$1"
if [ -z "$subnet" ]; then
    echo "Usage: $0 <subnet_last_octet>"
    exit 1
fi

# Crée des fichiers temporaires et setup cleanup automatique
tmpintdns=$(mktemp)
tmpextdns=$(mktemp)
tmpdhcp=$(mktemp)
allhosts=$(mktemp)
ipsfree=$(mktemp)

# Evite les fichiers tmp bidons
trap 'rm -f "$tmpintdns" "$tmpextdns" "$tmpdhcp" "$allhosts" "$ipsfree"' EXIT

# Récupère les IP du DNS Samba interne (samba-ad, à adapter)
ssh dc1 "samba-tool dns query $(hostname) $(hostname -d) @ ALL -P | grep -E '\b10\.20\.$subnet\.[0-9]+\b'" \
    | awk '{print $2}' > "$tmpintdns"

# Récupère les IP du DNS Bind9 externe
ssh ns1 "host -l entreprise.fr | grep -E '\b10\.20\.$subnet\.[0-9]+\b'" \
    | awk '{print $4}' > "$tmpextdns"

# Récupère les IP du DHCP (isc-dhcp)
ssh dhcp1 "grep -oP 'fixed-address\s+\K[0-9\.]+' /etc/dhcp/dhcpd.conf | grep -P '^10\.20\.$subnet\.'" \
    > "$tmpdhcp"

# Concatène toutes les listes et garde les IP uniques
cat "$tmpintdns" "$tmpextdns" "$tmpdhcp" | sort -u > "$allhosts"

# Boucle sur 254 pour trouver les IP libres
for i in {1..254}; do
    ip="10.20.$subnet.$i"
    grep -qx "$ip" "$allhosts" || echo "$ip"
done > "$ipsfree"

# There you go my friend
cat "$ipsfree"
