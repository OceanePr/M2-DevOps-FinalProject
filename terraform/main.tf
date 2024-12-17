provider "google" {
  project     = "devopsproject-65235"
  region      = "us-central1"
  credentials = file("C:/Users/ocean/Downloads/devopsproject-65235-63f22bae9ef1.json")
}

# Création d'une clé SSH pour se connecter à l'instance
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Enregistrement de la clé privée localement
resource "local_file" "ssh_key" {
  content  = tls_private_key.ssh_key.private_key_pem
  filename = "${path.module}/ml_instance_key.pem"
}

# Création de l'instance Compute Engine
resource "google_compute_instance" "ml_instance" {
  name         = "ml-instance"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  # Configuration de la clé SSH pour la connexion à l'instance
  metadata = {
    ssh-keys = "your-username:${tls_private_key.ssh_key.public_key_openssh}"
  }

  # Script de démarrage pour installer les outils de base
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io python3-pip
    systemctl start docker
    systemctl enable docker
    pip3 install mlflow
    nohup mlflow server --backend-store-uri sqlite:///mlflow.db --host 0.0.0.0 --port 5000 &
  EOF

  # Provisionner Ansible après le déploiement
  provisioner "local-exec" {
    command = "ansible-playbook -i ${self.network_interface[0].access_config[0].nat_ip}, --user=your-username --private-key=ml_instance_key.pem setup.yml"
  }
}

# Sortie de l'adresse IP publique de l'instance
output "instance_ip" {
  value = google_compute_instance.ml_instance.network_interface[0].access_config[0].nat_ip
}

# Sortie pour la clé SSH privée
output "ssh_key_location" {
  value = local_file.ssh_key.filename
}
