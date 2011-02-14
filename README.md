API Ruby pour Boursorama  
========================

Ceci est une bibliothèque en Ruby pour acceder aux service de banque en ligne de  [Boursorama](http://boursorama.com).

Pour accéder au code source : <http://github.com/hanklords/boursorama>

Utilisation
-----------

Voici comment utiliser la bibliothèque :

### Connexion

    require "boursorama"
    
    boursorama = Boursorama.new('...Identifiant...', '...Mot de passe...')

### Comptes

    boursorama.accounts.each {|account|
      puts account.name, account.number, account.total
    }

### Mouvements

Lister les mouvements sur le premier compte en décembre 2010 :

    boursorama.accounts.first.mouvements(Time.new(2010, 12))

### Relevés

Télécharger le dernier relevé de comptes :

    boursorama.accounts.first.releves.each {|releve|
      puts releve.name
      File.open(releve.name, "w") {|f| f.write releve.body}
    }

### Téléchargements

Télécharger les mouvements en format CSV :

    boursorama.accounts.first.telechargement_creation
    sleep 5 # Pause pour laisser le serveur traiter la demande...
    boursorama.accounts.first.telechargements.each {|r|
      puts r.name
      File.open(r.name, "w") {|f| f.write r.body}
    }
