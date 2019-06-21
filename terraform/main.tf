resource "openstack_blockstorage_volume_v2" "beeond_volume_master" {
  name 		= "${var.name_prefix}beeond_volume_master"
  size 		= "${var.beeond_disk_size}"
  volume_type 	= "${var.beeond_storage_backend}"
}

resource "openstack_blockstorage_volume_v2" "beeond_volume_compute" {
  count         = "${var.compute_node_count}"
  name          = "${var.name_prefix}beeond_volume_compute-${count.index}"
  size          = "${var.beeond_disk_size}"
  volume_type   = "${var.beeond_storage_backend}"
}


resource "openstack_compute_instance_v2" "master" {
  name            = "${var.name_prefix}master"
  flavor_name     = "${var.flavors["compute"]}"
  image_id        = "${openstack_images_image_v2.vuc-image-master.id}"
#  key_pair        = "${openstack_compute_keypair_v2.my-cloud-key.name}"
  key_pair        = "${var.openstack_key_name}"
  security_groups = "${var.security_groups}"
  network         = "${var.network}"

block_device {
    uuid                  = "${openstack_images_image_v2.vuc-image-master.id}"
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

block_device {
    uuid                  = "${openstack_blockstorage_volume_v2.beeond_volume_master.id}"
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = -1
    delete_on_termination = true
  }

  provisioner "remote-exec" {
    script = "mount_cinder_volumes.sh"

    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }

  provisioner "file" {
    content = "${tls_private_key.internal_connection_key.private_key_pem}"
    destination = "~/.ssh/connection_key.pem"  
  
    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  } 

  provisioner "remote-exec" {
    script = "public_key_to_authorized_key_file.sh"

    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "echo '${openstack_compute_instance_v2.master.access_ip_v4} ${var.name_prefix}master' >> /etc/hosts",
      "echo '${openstack_compute_instance_v2.compute.0.access_ip_v4} ${var.name_prefix}compute-node-0' >> /etc/hosts",
      "echo '${openstack_compute_instance_v2.compute.1.access_ip_v4} ${var.name_prefix}compute-node-1' >> /etc/hosts"
    ]

    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }
  
  provisioner "file" {
    source = "../configure_unicore"
    destination = "/usr/local/bin/configure_unicore"

    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }

  provisioner "file" {
    source = "../start_initial_unicore_cluster"
    destination = "/usr/local/bin/start_initial_unicore_cluster"

    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "start_initial_unicore_cluster"
    ]

    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }
}

resource "openstack_compute_instance_v2" "compute" {
  count           = "${var.compute_node_count}"
  name            = "${var.name_prefix}compute-node-${count.index}"
  flavor_name     = "${var.flavors["compute"]}"
  image_id        = "${openstack_images_image_v2.vuc-image-compute.id}"
#  key_pair        = "${openstack_compute_keypair_v2.my-cloud-key.name}"
  key_pair        = "${var.openstack_key_name}"
  security_groups = "${var.security_groups}"
  network         = "${var.network}"

block_device {
    uuid                  = "${openstack_images_image_v2.vuc-image-compute.id}"
    source_type           = "image"
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

block_device {
#    uuid                  = "${openstack_blockstorage_volume_v2.beeond_volume_compute.0.id}"
     uuid		  = "${count.index != "0" ? "${openstack_blockstorage_volume_v2.beeond_volume_compute.1.id}" : "${openstack_blockstorage_volume_v2.beeond_volume_compute.0.id}"}"
    source_type           = "volume"
    destination_type      = "volume"
    boot_index            = -1
    delete_on_termination = true
  }
  
  provisioner "remote-exec" {
    script = "mount_cinder_volumes.sh"
    
    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }

  provisioner "file" {
    content     = "${tls_private_key.internal_connection_key.private_key_pem}"
    destination = "~/.ssh/connection_key.pem"
    
    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }
  
  provisioner "remote-exec" {
    script = "public_key_to_authorized_key_file.sh"
    
    connection {
      type        = "ssh"
      private_key = "${file(var.private_key_path)}"
      user        = "centos"
      timeout     = "5m"
    }
  }
}






