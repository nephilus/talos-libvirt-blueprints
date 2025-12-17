terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

resource "libvirt_volume" "vm_disk" {
  for_each = var.vms

  name = "${each.value.vm_hostname}.raw"
  pool = "default"
  capacity = each.value.disk * 1024 * 1024 * 1024
}

resource "libvirt_domain" "vm" {
  for_each = var.vms

  name        = each.value.vm_hostname
  memory      = each.value.memory
  memory_unit = "GiB"
  vcpu        = each.value.vcpu
  type        = "kvm"
  autostart   = true
  running     = true

  cpu = {
    mode = "host-passthrough"
  }

  os = {
    type         = "hvm"
    type_arch    = "x86_64"
    type_machine = "pc-q35-rhel10.2.0"
    boot_devices = [
      { dev = "hd" },
      { dev = "cdrom" }
    ]
  }

  features = {
    acpi = true
    apic = {}
  }

  clock = {
    offset = "utc"
    timers = [
      { name = "rtc", tickpolicy = "catchup" },
      { name = "pit", tickpolicy = "delay" },
      { name = "hpet", present = "no" }
    ]
  }

  pm = {
    suspend_to_mem  = { enabled = "no" }
    suspend_to_disk = { enabled = "no" }
  }

  devices = {
    disks = [
      {
        type   = "file"
        device = "disk"
        driver = {
          name    = "qemu"
          type    = "raw"
          discard = "unmap"
        }
        source = {
         file = {
            file = libvirt_volume.vm_disk[each.key].id
          }
        }
        target = {
          dev = "vda"
          bus = "virtio"
        }
      },
      {
        type   = "file"
        device = "cdrom"
        driver = {
          name = "qemu"
          type = "raw"
        }
        source = {
          file = {
            file = var.iso_path
          }
        }
        target = {
          dev = "sda"
          bus = "sata"
        }
        readonly = true
      }
    ]

    interfaces = [
      {
        type = "network"
        mac  = {
          address = each.value.networks[0].mac
          type = "static"
        }
        source = {
          network = { network = coalesce(each.value.networks[0].network_name, var.networks["network1"].network_name) }
        }
        model = { type = "virtio" }
        addresses = [each.value.networks[0].ip]
      }
    ]

    consoles = [
      {
        type = "pty"
        target = {
          type = "serial"
        }
      }
    ]

    graphics = [
      {
        vnc = {
            type        = "vnc"
            listen_type = "address"
            autoport    = true
        }
      }
    ]

    videos = [
      {
        model = {
          type    = "virtio"
          heads   = 1
          primary = "yes"
        }
      }
    ]
  }
}