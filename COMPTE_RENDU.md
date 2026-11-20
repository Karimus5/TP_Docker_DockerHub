# TP Docker : commandes de base et partage sur Docker Hub — Compte rendu

Module DevOps, Pr. Imane CHLIOUI
Environnement : Windows 11, Docker Desktop 29.6.1 (moteur linux/amd64), 20 CPU, 7,6 GiB de RAM alloués à Docker.

---

## Partie 1 : premiers pas

### Exercice 1 : vérifier l'installation

```
$ docker version
Client 29.6.1 | Server 29.6.1 | linux/amd64

$ docker info
Containers=6 Running=2 Images=25 Storage=overlayfs OS=Docker Desktop CPUs=20 Mem=7.6GiB
```

Les deux parties répondent, **Client** et **Server**, donc le démon `dockerd` est bien démarré. Le client (la commande `docker`) ne fait qu'envoyer des requêtes à l'API du démon, et c'est le démon qui gère images, conteneurs, volumes et réseaux. Sous Windows, le démon tourne dans une petite VM Linux gérée par Docker Desktop. C'est pourquoi le serveur annonce `linux/amd64`.

### Exercice 2 : le premier conteneur

```
$ docker run hello-world
Unable to find image 'hello-world:latest' locally
latest: Pulling from library/hello-world
...
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

Les 4 étapes décrites par le message :
1. le **client** contacte le **démon** ;
2. le démon ne trouve pas l'image en local et la **télécharge depuis Docker Hub** (le registre) ;
3. le démon **crée un conteneur** à partir de l'image et l'exécute ;
4. le démon renvoie la sortie au client, qui l'affiche.

Lors d'une 2e exécution, l'étape 2 n'a plus lieu : l'image est déjà en cache local. Le conteneur s'arrête dès que son programme a fini d'écrire son message (état `Exited (0)`).

---

## Partie 2 : les images

### Exercice 3 : rechercher et télécharger

```
$ docker search nginx
NAME                              STARS     OFFICIAL
nginx                             21425     [OK]
nginx/nginx-ingress               124
nginx/nginx-prometheus-exporter   53
...

$ docker pull nginx:alpine ; docker pull nginx:latest
$ docker images nginx
REPOSITORY:TAG   IMAGE ID       SIZE
nginx:latest     84f7876d21d1   243MB
nginx:alpine     713fc2ebfd92   94.5MB
```

- Seule `nginx` porte la mention **OFFICIAL**. Les autres appartiennent au compte `nginx/…`, c'est-à-dire à l'éditeur.
- La variante `alpine` est environ **2,5 fois plus légère** (94,5 MB contre 243 MB), car elle est basée sur Alpine Linux et non sur Debian.
- Les deux tags ont des **IMAGE ID différents** : ce sont deux images distinctes, pas deux noms pour la même image.
- Nom complet d'une image : `registre/compte/dépôt:tag`. Ainsi `nginx` signifie en réalité `docker.io/library/nginx:latest`, comme le montre la sortie de `docker pull` (`docker.io/library/nginx:latest`).

### Exercice 4 : inspecter une image

Champs repérés dans `docker image inspect nginx:alpine` :

```
Cmd          = ["nginx","-g","daemon off;"]
Entrypoint   = ["/docker-entrypoint.sh"]
ExposedPorts = {"80/tcp":{}}
Env          = ["PATH=/usr/local/sbin:...", "NGINX_VERSION=1.31.8", "NJS_VERSION=1.0.2", ...]
```

- `Cmd` + `Entrypoint` : le conteneur exécute `/docker-entrypoint.sh nginx -g "daemon off;"`. `daemon off;` garde nginx au premier plan, sinon le conteneur s'arrêterait aussitôt.
- `ExposedPorts` : nginx écoute sur le port 80. C'est de la documentation : le port n'est pas publié automatiquement.
- `Env` : des variables d'environnement définies dans l'image, comme la version de nginx.

`docker history nginx:alpine` (extrait) :

```
SIZE      CREATED BY
52.4MB    RUN /bin/sh -c set -x && apkArch="$(cat …     <- installation de nginx
0B        CMD ["nginx" "-g" "daemon off;"]
0B        STOPSIGNAL SIGQUIT
0B        EXPOSE map[80/tcp:{}]
0B        ENTRYPOINT ["/docker-entrypoint.sh"]
16.4kB    COPY 30-tune-worker-processes.sh /docker-ent…
...
```

Chaque ligne est une couche et correspond à une instruction du Dockerfile. Les instructions de métadonnées (`CMD`, `EXPOSE`, `ENV`…) pèsent **0 B**. Seules celles qui modifient le système de fichiers (`RUN`, `COPY`) ont une taille.

Suppression de l'image inutile :
```
$ docker rmi nginx:latest
Deleted: sha256:84f7876d21d1...
$ docker images nginx
nginx:alpine
```

---

## Partie 3 : les conteneurs

### Exercice 5 : un conteneur interactif

```
$ docker run -it --rm ubuntu:24.04 bash
root@096e25372c7f:/# cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.5 LTS"
VERSION_CODENAME=noble
root@096e25372c7f:/# ps aux
USER  PID %CPU %MEM  ...  COMMAND
root    1  ...            bash
root    8  ...            ps aux
root@096e25372c7f:/# hostname
096e25372c7f
root@096e25372c7f:/# ls /home
ubuntu
root@096e25372c7f:/# exit
```

Observations :
- On est bien sur **Ubuntu 24.04**, alors que la machine hôte est sous Windows. Le conteneur apporte son propre système de fichiers, mais il partage le noyau Linux de la VM Docker.
- `ps aux` ne montre que **2 processus** : `bash`, en **PID 1**, et `ps`. Le conteneur est isolé dans son propre espace de processus (namespace PID) et ne voit aucun processus de l'hôte.
- Le `hostname` est l'**ID court du conteneur**.
- Après `exit`, bash (le PID 1) se termine, donc le conteneur s'arrête, et `--rm` le supprime : il n'apparaît pas dans `docker ps -a`.

| Option | Signification |
|---|---|
| `-i` | Garde l'entrée standard ouverte (interactif) |
| `-t` | Alloue un pseudo-terminal (invite, couleurs, Ctrl+C) |
| `--rm` | Supprime le conteneur dès qu'il s'arrête |

### Exercice 6 : un serveur web en arrière-plan

```
$ docker run -d --name web -p 8080:80 nginx:alpine
$ docker ps
CONTAINER ID   IMAGE          PORTS                                     NAMES
62f950ebe7f6   nginx:alpine   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   web
```

- `-d` (*detached*) : le conteneur tourne en arrière-plan et la commande rend la main en affichant l'ID.
- `-p 8080:80` : le port **8080 de l'hôte** est redirigé vers le port **80 du conteneur**, toujours dans l'ordre `hôte:conteneur`. `0.0.0.0` signifie que le port est accessible sur toutes les interfaces de la machine. La page « Welcome to nginx! » s'affiche sur http://localhost:8080.

### Exercice 7 : observer un conteneur

```
$ docker logs -f web
172.17.0.1 - - [20/Nov/2026:15:07:26 +0000] "GET / HTTP/1.1" 200 38 "-" "curl/8.16.0"
2026/11/20 15:07:26 [error] ... open() "/usr/share/nginx/html/inexistant" failed (2: No such file or directory)
172.17.0.1 - - [20/Nov/2026:15:07:26 +0000] "GET /inexistant HTTP/1.1" 404 153 "-" "curl/8.16.0"

$ docker stats
NAME   CPU %   MEM USAGE / LIMIT     NET I/O           PIDS
web    0.00%   15.93MiB / 7.609GiB   2.89kB / 1.97kB   21
```

- `docker logs` affiche ce que le processus principal écrit sur **stdout/stderr**. L'image nginx redirige ses fichiers `access.log` et `error.log` vers ces flux, d'où leur présence ici. Chaque rafraîchissement de la page ajoute une ligne. L'adresse `172.17.0.1` est la passerelle du réseau `bridge` : les requêtes arrivent de l'hôte à travers la redirection de port.
- `-f` (*follow*) suit les nouveaux journaux en continu, comme `tail -f`.
- `docker stats` montre que nginx au repos consomme environ **16 MiB** de RAM et 0 % de CPU. La limite affichée correspond à toute la mémoire de la VM Docker, faute de limite fixée avec `--memory`.

### Exercice 8 : entrer dans un conteneur et le modifier

```
$ docker exec -it web sh
/ # cd /usr/share/nginx/html
/usr/share/nginx/html # echo "<h1>Bonjour depuis mon conteneur</h1>" > index.html
/usr/share/nginx/html # exit

$ curl http://localhost:8080
<h1>Bonjour depuis mon conteneur</h1>
```

La page a changé immédiatement, sans redémarrer le conteneur.

- `docker exec` lance un **nouveau processus** dans un conteneur **déjà en cours d'exécution**. nginx reste le PID 1 (`nginx: master process`) et `sh` n'est qu'un processus supplémentaire. Quitter `sh` n'arrête donc pas le conteneur.
- `docker run` crée **toujours un nouveau conteneur** à partir d'une image.
- La modification est écrite dans la **couche inscriptible** du conteneur. L'image `nginx:alpine` n'est pas modifiée : un nouveau conteneur créé à partir d'elle affichera de nouveau « Welcome to nginx! ». C'est ce qu'on exploite à l'exercice 17 avec `docker commit`.

### Exercice 9 : le cycle de vie

(Le conteneur `web2` a été créé au préalable avec `docker run -d --name web2 -p 8081:80 nginx:alpine`.)

```
$ docker stop web2
$ docker ps              -> (vide) web2 n'apparaît plus
$ docker ps -a           -> web2   Exited (0) Less than a second ago
$ docker start web2      -> web2   Up Less than a second
$ docker rm web2
Error response from daemon: cannot remove container "web2": container is running:
stop the container before removing or force remove
$ docker rm -f web2      -> web2
```

Cycle de vie : `created → running → exited → (start) running → removed`.
- `stop` **arrête** le conteneur (SIGTERM, puis SIGKILL après 10 s) mais **ne le supprime pas** : il garde sa configuration et sa couche inscriptible, et `start` le relance tel quel.
- `docker ps` n'affiche que les conteneurs en cours d'exécution, `docker ps -a` les affiche tous.
- `rm` refuse de supprimer un conteneur qui tourne, par sécurité. `rm -f` force l'arrêt (SIGKILL) puis la suppression.

---

## Partie 4 : volumes

### Exercice 10 : les données d'un conteneur sont éphémères

```
$ docker run --name essai alpine sh -c "echo important > /donnee.txt"
$ docker rm essai
$ docker run --rm alpine cat /donnee.txt
cat: can't open '/donnee.txt': No such file or directory
```

Le fichier a été écrit dans la couche inscriptible du conteneur `essai`, et cette couche a disparu avec `docker rm`. Le nouveau conteneur repart de l'image `alpine` d'origine, qui ne contient pas le fichier. Un conteneur est donc **jetable** : toute donnée à conserver doit être stockée **hors du conteneur**.

### Exercice 11 : un volume nommé

```
$ docker volume create donnees
$ docker run --rm -v donnees:/data alpine sh -c "echo important > /data/note.txt"
$ docker run --rm -v donnees:/data alpine cat /data/note.txt
important

$ docker volume ls
DRIVER    VOLUME NAME
local     donnees

$ docker volume inspect donnees
[{ "CreatedAt": "2026-11-20T15:07:46Z", "Driver": "local",
   "Mountpoint": "/var/lib/docker/volumes/donnees/_data",
   "Name": "donnees", "Scope": "local" }]
```

- Le premier conteneur a été supprimé (`--rm`), mais le fichier a **survécu** et un **autre** conteneur l'a relu. Le volume a une vie **indépendante** des conteneurs.
- `Mountpoint` indique où Docker stocke les données. Sous Docker Desktop, ce chemin se trouve dans la VM Linux et n'est pas directement visible depuis l'Explorateur Windows.
- Usage typique : les données d'une base de données (par exemple `-v pgdata:/var/lib/postgresql/data`).

---

## Partie 6 : partager sur Docker Hub

Principe : `docker login` → `docker tag` (nom `identifiant/dépôt:tag`) → `docker push` → sur une autre machine, `docker pull` / `docker run`.

### Exercice 16 : compte et jeton d'accès

1. Compte gratuit (offre Personal) créé sur hub.docker.com. Identifiant : **`<IDENTIFIANT>`**.
2. *Account settings → Personal access tokens* : jeton `tp-devops`, droits **Read & Write**.
3. Connexion en collant le jeton à la place du mot de passe :

```
$ docker login -u <IDENTIFIANT>
Password:
Login Succeeded
```

Un jeton est préférable au mot de passe : ses droits sont limités (ici Read & Write, sans administration du compte) et on peut le **révoquer** à tout moment sans changer de mot de passe. Docker Desktop range les identifiants dans le gestionnaire d'identifiants de Windows (`"credsStore": "desktop"` dans `~/.docker/config.json`) et non en clair dans le fichier.

### Exercice 17 : figer le conteneur, l'étiqueter et le pousser

```
$ docker commit -m "Page d'accueil personnalisée" web <IDENTIFIANT>/nginx-perso:1.0
sha256:5512b1943f99a...

$ docker history <IDENTIFIANT>/nginx-perso:1.0
SIZE      CREATED BY              COMMENT
90.1kB    nginx -g daemon off;    Page d'accueil personnalisée    <- nouvelle couche = modifications du conteneur
52.4MB    RUN /bin/sh -c set -x … buildkit.dockerfile.v0          <- couches de nginx:alpine, réutilisées

$ docker push <IDENTIFIANT>/nginx-perso:1.0
The push refers to repository [docker.io/<IDENTIFIANT>/nginx-perso]
...: Mounted from library/nginx
...: Pushed
1.0: digest: sha256:... size: ...
```

Vérification locale avant le push : un conteneur lancé depuis la nouvelle image (`-p 8082:80`) affiche bien `<h1>Bonjour depuis mon conteneur</h1>`. La modification de l'exercice 8 fait désormais partie d'une image.

Remarques :
- `docker commit` ajoute **une seule couche** (90 kB) contenant les différences du conteneur par rapport à son image. Les couches de `nginx:alpine` sont réutilisées. Au push, Docker Hub les possède déjà (« Mounted from library/nginx »), donc seule la nouvelle couche est envoyée.
- `docker tag` **n'effectue aucune copie** : il ajoute simplement un nom qui pointe vers le même IMAGE ID.
- Le préfixe doit être **exactement** l'identifiant Docker Hub, sinon on obtient `denied: requested access to the resource is denied`.
- `docker commit` est pratique pour une démonstration, mais c'est une **mauvaise pratique** en production : l'image n'est pas reproductible, car on ne sait pas comment elle a été obtenue. Il faut lui préférer un **Dockerfile** (`FROM nginx:alpine` + `COPY index.html /usr/share/nginx/html/`), versionné dans Git.
- L'énoncé contient deux coquilles. Il y a un espace en trop dans `etudiant-a/ nginx-perso`, ce qui rend le nom invalide. Et la ligne `docker tag monapp:1.1 …` concerne l'image `monapp` des exercices 12 à 15 et 18, qui ne figurent pas dans le sujet fourni.

### Exercice 19 : récupérer l'image d'un camarade

```
# Supprimer sa propre copie locale pour vérifier le téléchargement
$ docker rmi <IDENTIFIANT>/nginx-perso:1.0 nginx-perso:1.0

# Lancer l'image du camarade (téléchargée automatiquement)
$ docker run -d --name voisin-web -p 8083:80 <IDENTIFIANT_CAMARADE>/nginx-perso:1.0
Unable to find image '<IDENTIFIANT_CAMARADE>/nginx-perso:1.0' locally
1.0: Pulling from <IDENTIFIANT_CAMARADE>/nginx-perso
...
$ curl http://localhost:8083     -> page personnalisée du camarade
```

`docker run` fait un `pull` implicite quand l'image est absente en local. N'importe quelle machine équipée de Docker obtient exactement la même image, identifiée par son *digest* `sha256`. C'est le principe du « build once, run anywhere ». Un dépôt public peut être téléchargé sans `docker login` ; un dépôt privé exige d'être connecté avec un compte autorisé.

---

## Partie 7 : nettoyage

### Exercice 20 : faire le ménage

```
$ docker ps -a
$ docker rm -f web web-dev serveur voisin voisin-web
$ docker network rm labo
$ docker volume rm donnees
$ docker system df          # espace occupé par images, conteneurs, volumes, cache
```

- Il faut supprimer les conteneurs **avant** le volume et le réseau : un volume ou un réseau encore utilisé par un conteneur ne peut pas être supprimé.
- `docker volume rm` **détruit définitivement** les données : c'est la seule commande du TP qui perd des données « persistantes ».
- `docker system prune` supprime d'un coup les conteneurs arrêtés, les réseaux inutilisés, les images orphelines et le cache de build. Avec `-a --volumes`, il va beaucoup plus loin et doit être utilisé avec prudence.

---

## Synthèse

| Notion | À retenir |
|---|---|
| Client / démon / registre | `docker` envoie des ordres à `dockerd`, qui télécharge les images depuis un registre (Docker Hub par défaut) |
| Image | Modèle en lecture seule, composé de couches empilées. Nom complet : `registre/compte/dépôt:tag` |
| Conteneur | Instance d'une image, avec une couche inscriptible éphémère. Il vit tant que son PID 1 vit |
| `run` / `exec` | `run` crée un nouveau conteneur ; `exec` lance une commande dans un conteneur existant |
| `stop` / `rm` | `stop` arrête, `rm` supprime ; `rm -f` fait les deux |
| `-p hôte:conteneur` | Publie un port ; `EXPOSE` ne fait que le documenter |
| Volume | Stockage persistant, indépendant du cycle de vie des conteneurs |
| `commit` / `tag` / `push` | Figer un conteneur en image, la nommer `identifiant/dépôt:tag`, la publier |
| Jeton d'accès | Plutôt que le mot de passe : droits limités et révocable |
