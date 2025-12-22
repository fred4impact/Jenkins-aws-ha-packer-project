# Ansible Playbooks for Jenkins Configuration

This directory contains Ansible playbooks and roles for configuring Jenkins Master during the Packer AMI build process.

## Structure

```
playbooks/
├── jenkins-setup.yml          # Main playbook
├── ansible.cfg                # Ansible configuration
├── hosts                      # Inventory file
├── group_vars/
│   └── all.yml               # Global variables
└── roles/
    ├── jenkins/               # Jenkins configuration role
    │   ├── tasks/
    │   │   ├── main.yml
    │   │   ├── RedHat.yml
    │   │   ├── Debian.yml
    │   │   ├── install-plugins.yml
    │   │   ├── configure-jenkins.yml
    │   │   ├── security.yml
    │   │   ├── cli-setup.yml
    │   │   └── ha-config.yml
    │   ├── handlers/
    │   │   └── main.yml
    │   ├── templates/
    │   │   ├── jenkins-config.xml.j2
    │   │   ├── jenkins-location.xml.j2
    │   │   ├── jenkins-security.xml.j2
    │   │   ├── jenkins-cli.sh.j2
    │   │   ├── jenkins-ha-config.xml.j2
    │   │   └── ha-setup.sh.j2
    │   └── vars/
    │       └── main.yml
    └── security/               # Security hardening role
        ├── tasks/
        │   ├── main.yml
        │   ├── RedHat.yml
        │   ├── Debian.yml
        │   ├── os-updates.yml
        │   ├── firewall.yml
        │   ├── ssh-hardening.yml
        │   ├── system-security.yml
        │   └── security-tools.yml
        ├── handlers/
        │   └── main.yml
        ├── templates/
        │   ├── 50unattended-upgrades.j2
        │   ├── jail.local.j2
        │   ├── login.defs.j2
        │   ├── system-auth.j2
        │   └── logrotate-security.j2
        └── vars/
            └── main.yml
```

## Usage

### With Packer

The playbook is called from Packer during the AMI build:

```hcl
provisioner "ansible" {
  playbook_file = "../playbooks/jenkins-setup.yml"
  extra_arguments = [
    "--extra-vars", "jenkins_version=2.414.3",
    "--extra-vars", "java_version=17"
  ]
}
```

### Standalone Execution

To run the playbook directly:

```bash
cd playbooks
ansible-playbook -i hosts jenkins-setup.yml
```

### With Tags

Run specific parts of the playbook:

```bash
# Only security tasks
ansible-playbook -i hosts jenkins-setup.yml --tags security

# Only Jenkins configuration
ansible-playbook -i hosts jenkins-setup.yml --tags jenkins

# Only OS updates
ansible-playbook -i hosts jenkins-setup.yml --tags os-updates
```

## Roles

### Jenkins Role

Configures Jenkins Master with:
- Jenkins installation
- Required plugins
- System configuration
- Security settings
- HA configuration
- CLI setup

### Security Role

Applies security hardening:
- OS updates and security patches
- Firewall configuration
- SSH hardening
- System security parameters
- Security tools (fail2ban, AIDE, etc.)

## Variables

Key variables can be overridden in `group_vars/all.yml` or via command line:

```bash
ansible-playbook -i hosts jenkins-setup.yml \
  -e "jenkins_version=2.415.0" \
  -e "java_version=17"
```

## Requirements

- Ansible >= 2.9
- Python 3
- Root/sudo access on target system

## Notes

- The playbook is designed to run on `localhost` during Packer build
- OS-specific tasks are included for RedHat and Debian families
- All configurations are idempotent (safe to run multiple times)



