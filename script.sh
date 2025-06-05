#!/bin/bash

DMZ_VM_IP="172.16.2.15"
HOST_IP="10.0.0.35"     # Exemple: IP de votre machine hôte

# activer routage : 
systemctl -w net.ipv4.ip_forward=1

echo "Démarrage et activation de firewalld..."
systemctl enable --now firewalld

echo "Nettoyage des règles de transfert permanentes existantes..."
firewall-cmd --zone=internal --remove-forward --permanent 2>/dev/null
firewall-cmd --zone=dmz --remove-forward --permanent 2>/dev/null
firewall-cmd --zone=public --remove-forward --permanent 2>/dev/null

echo "Nettoyage des services personnalisés et des politiques existantes..."
firewall-cmd --delete-service=web8080 --permanent 2>/dev/null
firewall-cmd --delete-policy=internal-to-public --permanent 2>/dev/null
firewall-cmd --delete-policy=internal-to-dmz-ping --permanent 2>/dev/null
firewall-cmd --delete-policy=dmz-to-internal-ping --permanent 2>/dev/null
firewall-cmd --delete-policy=internal-to-dmz-ssh-ftp --permanent 2>/dev/null
firewall-cmd --delete-policy=containers-to-public --permanent 2>/dev/null
firewall-cmd --delete-policy=containers-to-dmz --permanent 2>/dev/null
firewall-cmd --delete-policy=containers-to-internal --permanent 2>/dev/null
firewall-cmd --delete-policy=int-to-dmz-ping --permanent 2>/dev/null
firewall-cmd --delete-policy=dmz-to-int-ping --permanent 2>/dev/null
firewall-cmd --delete-policy=int-to-dmz-ssh-ftp --permanent 2>/dev/null
firewall-cmd --delete-policy=cont-to-public --permanent 2>/dev/null
firewall-cmd --delete-policy=cont-to-dmz --permanent 2>/dev/null
firewall-cmd --delete-policy=cont-to-internal --permanent 2>/dev/null

firewall-cmd --delete-zone=containers --permanent 2>/dev/null

# Recharger firewalld pour appliquer le nettoyage initial
firewall-cmd --reload

echo "Assignation des interfaces aux zones..."
firewall-cmd --zone=public --change-interface=ens192 --permanent
firewall-cmd --zone=internal --change-interface=ens224 --permanent
firewall-cmd --zone=dmz --change-interface=ens256 --permanent

echo "Définition des cibles par défaut pour les zones..."
firewall-cmd --zone=dmz --set-target=DROP --permanent
firewall-cmd --zone=public --set-target=DROP --permanent
firewall-cmd --zone=internal --set-target=ACCEPT --permanent

echo "Activation de la journalisation des paquets refusés..."
firewall-cmd --set-log-denied=all

echo "Ajout des services autorisés sur le pare-feu..."

firewall-cmd --zone=internal --add-service=dns --permanent
firewall-cmd --zone=internal --add-service=http --permanent
firewall-cmd --zone=internal --add-service=https --permanent

# Autoriser le ping vers le pare-feu depuis les zones internal et dmz
firewall-cmd --zone=internal --add-protocol=icmp --permanent
firewall-cmd --zone=dmz --add-protocol=icmp --permanent

# --- ÉTAPE 6: Masquage (Source NAT) pour l'accès Internet ---
echo "Activation du masquage (Source NAT) sur la zone public..."
firewall-cmd --zone=public --add-masquerade --permanent

# --- ÉTAPE 7: Création d'un service personnalisé pour le port 8080 ---
echo "Création du service personnalisé pour le port 8080..."
firewall-cmd --new-service=web8080 --permanent
firewall-cmd --service=web8080 --add-port=8080/tcp --permanent

# --- ÉTAPE 8: Définition des politiques (Inter-zone traffic) ---
echo "Définition des politiques de routage inter-zones..."

# Policy: internal-to-public (HTTP/HTTPS/DNS)
firewall-cmd --new-policy=internal-to-public --permanent
firewall-cmd --policy=internal-to-public --add-ingress-zone=internal --permanent
firewall-cmd --policy=internal-to-public --add-egress-zone=public --permanent
firewall-cmd --policy=internal-to-public --set-target=ACCEPT --permanent
firewall-cmd --policy=internal-to-public --add-service=http --permanent
firewall-cmd --policy=internal-to-public --add-service=https --permanent
firewall-cmd --policy=internal-to-public --add-service=dns --permanent

# Policy: internal-to-dmz-ping (raccourci)
firewall-cmd --new-policy=int-to-dmz-ping --permanent
firewall-cmd --policy=int-to-dmz-ping --add-ingress-zone=internal --permanent
firewall-cmd --policy=int-to-dmz-ping --add-egress-zone=dmz --permanent
firewall-cmd --policy=int-to-dmz-ping --set-target=ACCEPT --permanent
firewall-cmd --policy=int-to-dmz-ping --add-protocol=icmp --permanent

# Policy: dmz-to-internal-ping (raccourci)
firewall-cmd --new-policy=dmz-to-int-ping --permanent
firewall-cmd --policy=dmz-to-int-ping --add-ingress-zone=dmz --permanent
firewall-cmd --policy=dmz-to-int-ping --add-egress-zone=internal --permanent
firewall-cmd --policy=dmz-to-int-ping --set-target=ACCEPT --permanent
firewall-cmd --policy=dmz-to-int-ping --add-protocol=icmp --permanent

# Policy: internal-to-dmz-ssh-ftp (raccourci)
firewall-cmd --new-policy=int-to-dmz-ssh-ftp --permanent
firewall-cmd --policy=int-to-dmz-ssh-ftp --add-ingress-zone=internal --permanent
firewall-cmd --policy=int-to-dmz-ssh-ftp --add-egress-zone=dmz --permanent
firewall-cmd --policy=int-to-dmz-ssh-ftp --set-target=ACCEPT --permanent
firewall-cmd --policy=int-to-dmz-ssh-ftp --add-service=ssh --permanent
firewall-cmd --policy=int-to-dmz-ssh-ftp --add-service=ftp --permanent

# Policy pour les conteneurs
echo "Définition des politiques pour les conteneurs..."
firewall-cmd --new-zone=containers --permanent
firewall-cmd --zone=containers --add-interface=docker0 --permanent

# Policy: containers-to-public (raccourci)
firewall-cmd --new-policy=cont-to-public --permanent
firewall-cmd --policy=cont-to-public --add-ingress-zone=containers --permanent
firewall-cmd --policy=cont-to-public --add-egress-zone=public --permanent
firewall-cmd --policy=cont-to-public --set-target=ACCEPT --permanent

# Policy: containers-to-dmz (raccourci)
firewall-cmd --new-policy=cont-to-dmz --permanent
firewall-cmd --policy=cont-to-dmz --add-ingress-zone=containers --permanent
firewall-cmd --policy=cont-to-dmz --add-egress-zone=dmz --permanent
firewall-cmd --policy=cont-to-dmz --set-target=DROP --permanent

# Policy: containers-to-internal (raccourci)
firewall-cmd --new-policy=cont-to-internal --permanent
firewall-cmd --policy=cont-to-internal --add-ingress-zone=containers --permanent
firewall-cmd --policy=cont-to-internal --add-egress-zone=internal --permanent
firewall-cmd --policy=cont-to-internal --set-target=DROP --permanent

# Destination NAT (Port Forwarding) sur la zone public ---
echo "Définition des règles de Destination NAT (Port Forwarding) sur la zone public..."

# DNAT pour SSH camouflé (port 4321 externe vers port 22 interne sur la VM DMZ)
firewall-cmd --zone=public --add-forward-port=port=4321:proto=tcp:toport=22:toaddr="${DMZ_VM_IP}" --permanent

# DNAT pour le service web HTTP (port 80 externe vers port 80 interne sur la VM DMZ)
firewall-cmd --zone=public --add-forward-port=port=80:proto=tcp:toaddr="${DMZ_VM_IP}" --permanent

# DNAT pour le service web HTTPS (port 443 externe vers port 443 interne sur la VM DMZ)
firewall-cmd --zone=public --add-forward-port=port=443:proto=tcp:toaddr="${DMZ_VM_IP}" --permanent

# DNAT pour le service web personnalisé (port 8080 externe vers port 8080 interne sur la VM DMZ)
firewall-cmd --zone=public --add-forward-port=port=8080:proto=tcp:toaddr="${DMZ_VM_IP}" --permanent

# Rich Rule pour SSH sur le pare-feu depuis l'hôte (zone public) ---
echo "Ajout de la Rich Rule pour SSH sur le pare-feu depuis l'hôte..."
firewall-cmd --zone=public --add-rich-rule='rule family="ipv4" source address="'"${HOST_IP}"'" service name="ssh" accept' --permanent

# Rechargement de firewalld ---
echo "Rechargement de firewalld pour appliquer toutes les modifications permanentes..."
firewall-cmd --reload

echo "Configuration firewalld appliquée avec succès"


history -d $(history | tail -n 2 | head -n 1 | awk '{print $1}'); history -d $(history | tail -n 1 | awk '{print $1}')
