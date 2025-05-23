
# Configure provider in terraform code
provider "google" {
  project     = var.project
  region      = var.region
  zone        = var.zone
  credentials = file (var.google_credentials)
}

# Enable compute Engine API

/*resource "google_project_service" "compute" {
  project = var.project
  service = "compute.googleapis.com"
}
*/


# VPC creation
resource "google_compute_network" "vpc_network" {
  name = "cluster-network"
  # depends_on = [google_project_service.compute ]
}

resource "google_compute_subnetwork" "subnet" {
    name = "private-subnet"
    ip_cidr_range = "10.0.0.0/16"
    region = "us-central1"
    network = google_compute_network.vpc_network.id
}


resource "google_compute_firewall" "fw" {
  name    = "cluster-firewall"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["80", "8080", "22"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags = ["web"]
}

resource "google_compute_firewall" "allow_control_plane" {
  name    = "allow-control-plane"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["6443", "2379-2380", "10250", "10259", "10257"]
  }

  source_ranges = ["0.0.0.0/0"]  # Or your admin IPs
  target_tags   = ["control-plane"]

  description = "ports for control plane"

  
}

resource "google_compute_firewall" "ssh_control_plane" {
  name    = "ssh-control-plane"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.0.0.0/16"]  
  target_tags   = ["control-plane"]

  
}
resource "google_compute_firewall" "allow_worker_node" {
  name    = "allow-worker-node"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["30000-32767", "10250", "10256"]
  }
    allow {
    protocol = "udp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]  # Or your admin IPs
  target_tags   = ["worker-node"]

  description = "ports for worker node"
}

resource "google_compute_firewall" "ssh_worker_node" {
  name    = "ssh-worker-node"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }


  source_ranges = ["10.0.0.0/16"]  
  target_tags   = ["worker-node"]

}

/*
resource "google_compute_firewall" "allow_etcd_api" {
  name    = "allow-etcd-api"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["2379-2380"]
  }

  source_tags = ["control-plane"]
  target_tags = ["control-plane"]

  description = "Allow etcd API access from kube-apiserver"
}

resource "google_compute_firewall" "kubelet_api_control" {
  name    = "allow-kubelet-api"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["10250"]
  }

  source_tags = ["control-plane"]
  target_tags = ["control-plane"]

  description = "Allow kubelet API access from control-plane"
}

resource "google_compute_firewall" "allow_scheduler" {
  name    = "allow-kube-scheduler"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["10259"]
  }


  source_tags = ["control-plane"]
  target_tags = ["control-plane"]

  description = "Allow kube-scheduler access (self)"
}

resource "google_compute_firewall" "allow_controller" {
  name    = "allow-kube-controller"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["10257"]
  }

  source_tags = ["control-plane"]
  target_tags = ["control-plane"]

  description = "Allow kube-controller-manager access (self)"
}

resource "google_compute_firewall" "kubelet_api_worker" {
  name    = "kubelet-api"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["10250"]
  }

  source_tags = ["control-plane"]
  target_tags = ["worker-node"]

  
}

resource "google_compute_firewall" "kube_proxy" {
  name    = "allow-kube-proxy"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["10256"]
  }

  source_tags = ["load-balancer"]
  target_tags = ["worker-node"]

  
}

resource "google_compute_firewall" "nodeport" {
  name    = "allow-node-port"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "tcp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["worker-node"]

  
}

resource "google_compute_firewall" "udp-nodeport" {
  name    = "udp-allow-node-port"
  network = google_compute_network.vpc_network.name

  direction = "INGRESS"
  priority  = 1000

  allow {
    protocol = "udp"
    ports    = ["30000-32767"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["worker-node"]

  
}
*/

resource "google_compute_router" "router" {
  name    = "router"
  network = google_compute_network.vpc_network.name
  region = var.region
}

resource "google_compute_router_nat" "nat" {
  name                               = "router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  enable_endpoint_independent_mapping = true


}

# control node
 resource "google_compute_instance" "control" {
  name         = "control-node"
  machine_type = "e2-small"
  zone         = var.zone

  tags = ["control-plane"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      labels = {
        my_label = "control-node"
      }
    }
  }


  network_interface {
    network = "cluster-network"
    subnetwork = "private-subnet"
  

#    access_config {
#      # Empty block means ephemeral external IP will be assigned
#    }
  }
  metadata = {
    ssh-keys = "maham-bhatti:${file("~/.ssh/my-gcp-key.pub")}"
  }

}

# worker node 1
 resource "google_compute_instance" "worker_1" {
  name         = "worker-1"
  machine_type = "e2-small"
  zone         = var.zone

  tags = ["worker-node"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      labels = {
        my_label = "worker-node"
      }
    }
  }


  network_interface {
    network = "cluster-network"
    subnetwork = "private-subnet"
  

#    access_config {
#      # Empty block means ephemeral external IP will be assigned
#    }
  }
  metadata = {
    ssh-keys = "maham-bhatti:${file("~/.ssh/my-gcp-key.pub")}"
  }

}

# worker node 2
 resource "google_compute_instance" "worker_2" {
  name         = "worker-2"
  machine_type = "e2-small"
  zone         = var.zone

  tags = ["worker-node"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      labels = {
        my_label = "worker-node"
      }
    }
  }


  network_interface {
    network = "cluster-network"
    subnetwork = "private-subnet"
  

#    access_config {
#      # Empty block means ephemeral external IP will be assigned
#    }
  }
  metadata = {
    ssh-keys = "maham-bhatti:${file("~/.ssh/my-gcp-key.pub")}"
  }

}

# bastion
 resource "google_compute_instance" "bastion" {
  name         = "bastion"
  machine_type = "e2-small"
  zone         = var.zone

  tags = ["web"]

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-2204-lts"
      labels = {
        my_label = "bastion"
      }
    }
  }


  network_interface {
    network = "cluster-network"
    subnetwork = "private-subnet"
  

    access_config {
      # Empty block means ephemeral external IP will be assigned
    }
  }
  metadata = {
    ssh-keys = "maham-bhatti:${file("~/.ssh/my-gcp-key.pub")}"
  }

}

