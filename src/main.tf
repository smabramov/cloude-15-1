terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = "~>1.8.4"
}

provider "yandex" {
  cloud_id                 = "b1gttf81lmg2v759uobi"
  folder_id                = "b1g8381i07tsfq06pnmc"

  zone                     = "ru-central1-a" # Зона доступности по умолчанию
  service_account_key_file = file("~/key.json")
}


data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2004-lts" 
}


resource "yandex_compute_instance" "nat-instance" {
  
  name = "nat-instance"
  allow_stopping_for_update = true
    resources {
    cores  = 2
    memory = 2
    core_fraction = 20
    
    }
    scheduling_policy {
    preemptible = true
    
    }
    boot_disk {

    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
      size = 20
    }
 
    }
    network_interface {

    subnet_id          = yandex_vpc_subnet.public.id

    nat                = true
    ip_address = "192.168.10.254"
    }
    metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
resource "yandex_compute_instance" "vm-1" {
  count = 1
  name = "control-node-${count.index + 1}"
    resources {
    cores  = 2
    memory = 2
    core_fraction = 20

    }
    scheduling_policy {
    preemptible = true
    }
    boot_disk {

    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size = 20
    }
    
    }
    network_interface {

    subnet_id          = yandex_vpc_subnet.public.id

    nat                = true
    }
    metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}
resource "yandex_compute_instance" "vm-2" {
  count = 1
  name = "worker-node-${count.index + 1}"
    resources {
    cores  = 2
    memory = 2
    core_fraction = 20

    }
    scheduling_policy {
    preemptible = true
    }
    boot_disk {

    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.image_id
      size = 20
    }
    
    }
    network_interface {

    subnet_id          = yandex_vpc_subnet.private.id

    nat                = false
    }
    metadata = {
    ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
  }
}

resource "yandex_vpc_network" "VPC" {
  name = "VPC"
}

resource "yandex_vpc_subnet" "public" {
  zone           = "ru-central1-a"
  name = "public"
  network_id     = "${yandex_vpc_network.VPC.id}"
  v4_cidr_blocks = ["192.168.10.0/24"]

}
resource "yandex_vpc_subnet" "private" {
  zone           = "ru-central1-a"
  name = "private"
  network_id     = "${yandex_vpc_network.VPC.id}"
  v4_cidr_blocks = ["192.168.20.0/24"]
  route_table_id = yandex_vpc_route_table.nat-instance-route.id
 }
#Создание таблицы маршрутизации и статического маршрута

resource "yandex_vpc_route_table" "nat-instance-route" {
  name       = "nat-instance-route"
  network_id = "${yandex_vpc_network.VPC.id}"
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat-instance.network_interface.0.ip_address
  }
}


