# Ansible Role: app_deploy

This role deploys the Java CRUD application to the target server.

## Requirements

- Ubuntu 22.04
- Sudo privileges
- Python 3

## Role Variables

```yaml
app_user: ubuntu
app_dir: /opt/app
app_jar_name: app.jar
app_port: 8080
java_home: /usr/lib/jvm/java-17-openjdk-amd64

# From Jenkins pipeline
artifact_version: "1.0.0"
artifact_id: "crud-app"
group_id: "com.devopslab"
nexus_url: "http://nexus:8081"
nexus_repository: "maven-releases"
nexus_user: "admin"
nexus_password: "Admin123!"
```

## Dependencies

None

## Example Playbook

```yaml
- hosts: app_server
  roles:
    - app_deploy
```

## Tasks

1. Install Java 17
2. Create application directory
3. Download artifact from Nexus
4. Create systemd service
5. Start application
6. Verify health endpoint
