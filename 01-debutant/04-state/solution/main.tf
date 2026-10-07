terraform {
  required_version = ">= 1.7.0" # le bloc removed{} exige 1.7+
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Étape 1 : appliquez avec le nom "ancien", puis renommez en "nouveau"
# et ajoutez le bloc moved : Terraform renomme dans le state SANS détruire.
resource "random_pet" "nouveau" {
  length = 3
}

moved {
  from = random_pet.ancien
  to   = random_pet.nouveau
}

resource "local_file" "trace" {
  filename = "${path.module}/out/trace.txt"
  content  = random_pet.nouveau.id
}

# Étape 2 : "oublier" une ressource sans la détruire (removed, TF >= 1.7)
# Décommentez après l'avoir supprimée du code :
# removed {
#   from = local_file.trace
#   lifecycle {
#     destroy = false
#   }
# }

# Étape 3 (import déclaratif, TF >= 1.5) : voir le README.
