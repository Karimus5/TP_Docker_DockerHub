#!/bin/sh
# TP Docker : commandes de base et partage sur Docker Hub
# Commandes exécutées pendant le TP, exercice par exercice.
# À lancer une par une (certaines sont interactives) : ce n'est pas un script à exécuter d'un bloc.
# Remplacer <IDENTIFIANT> par son identifiant Docker Hub.

# ===== Partie 1 : premiers pas =====

# Exercice 1 : vérifier l'installation
docker version
docker info

# Exercice 2 : le premier conteneur
docker run hello-world

# ===== Partie 2 : les images =====

# Exercice 3 : rechercher et télécharger
docker search nginx
docker pull nginx:alpine
docker pull nginx:latest
docker images nginx

# Exercice 4 : inspecter une image
docker image inspect nginx:alpine
docker history nginx:alpine
docker rmi nginx:latest
docker images nginx

# ===== Partie 3 : les conteneurs =====

# Exercice 5 : un conteneur interactif
docker run -it --rm ubuntu:24.04 bash
#   dans le conteneur : cat /etc/os-release ; ps aux ; hostname ; ls /home ; exit

# Exercice 6 : un serveur web en arrière-plan
docker run -d --name web -p 8080:80 nginx:alpine
docker ps
#   puis ouvrir http://localhost:8080

# Exercice 7 : observer un conteneur
docker logs -f web
docker stats

# Exercice 8 : entrer dans un conteneur et le modifier
docker exec -it web sh
#   dans le conteneur :
#   cd /usr/share/nginx/html
#   echo "<h1>Bonjour depuis mon conteneur</h1>" > index.html
#   exit
curl http://localhost:8080

# Exercice 9 : le cycle de vie
docker run -d --name web2 -p 8081:80 nginx:alpine
docker stop web2
docker ps
docker ps -a
docker start web2
docker rm web2        # refusé : le conteneur tourne
docker rm -f web2

# ===== Partie 4 : volumes =====

# Exercice 10 : les données d'un conteneur sont éphémères
docker run --name essai alpine sh -c "echo important > /donnee.txt"
docker rm essai
docker run --rm alpine cat /donnee.txt     # le fichier n'existe plus

# Exercice 11 : un volume nommé
docker volume create donnees
docker run --rm -v donnees:/data alpine sh -c "echo important > /data/note.txt"
docker run --rm -v donnees:/data alpine cat /data/note.txt
docker volume ls
docker volume inspect donnees

# ===== Partie 6 : partager sur Docker Hub =====

# Exercice 16 : connexion avec un jeton d'accès (Read & Write)
docker login -u <IDENTIFIANT>

# Exercice 17 : figer le conteneur, l'étiqueter et le pousser
docker commit -m "Page d'accueil personnalisée" web <IDENTIFIANT>/nginx-perso:1.0
docker history <IDENTIFIANT>/nginx-perso:1.0
docker run -d --name web-test -p 8082:80 <IDENTIFIANT>/nginx-perso:1.0
curl http://localhost:8082
docker push <IDENTIFIANT>/nginx-perso:1.0

# Variante reproductible avec un Dockerfile (dossier nginx-perso/)
docker build -t <IDENTIFIANT>/nginx-perso:1.1 nginx-perso
docker push <IDENTIFIANT>/nginx-perso:1.1

# Exercice 19 : récupérer l'image d'un camarade
docker rmi <IDENTIFIANT>/nginx-perso:1.0
docker run -d --name voisin-web -p 8083:80 <IDENTIFIANT_CAMARADE>/nginx-perso:1.0
curl http://localhost:8083

# ===== Partie 7 : nettoyage =====

# Exercice 20 : faire le ménage
docker ps -a
docker rm -f web web-test voisin-web
docker volume rm donnees
docker system df
