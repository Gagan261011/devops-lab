# ONE-CLICK DEVOPS LAB DEPLOYMENT

## What I Fixed

All scripts are now **FULLY AUTOMATED**. No manual configuration needed!

### Key Changes:

1. **Jenkins (`cloud-init/jenkins.sh`)**:
   - ✅ Automatically installs ALL plugins
   - ✅ Creates admin user (admin/Admin123!)
   - ✅ Creates ALL credentials (SonarQube token, Nexus, Ansible SSH)
   - ✅ Configures Maven, JDK, SonarQube server
   - ✅ **AUTOMATICALLY CREATES THE PIPELINE JOB** 
   - ✅ Sets global environment variables (NEXUS_URL, SONAR_HOST_URL)
   - ✅ Background process updates SonarQube token when ready

2. **SonarQube (`cloud-init/sonar.sh`)**:
   - ✅ Automatically changes admin password to Admin123!
   - ✅ Generates Jenkins token automatically
   - ✅ Runs in background, no delays

3. **Nexus (`cloud-init/nexus.sh`)**:
   - ✅ Automatically changes admin password to Admin123!
   - ✅ Disables anonymous access
   - ✅ Runs in background

4. **Jenkinsfile**:
   - ✅ Reads NEXUS_URL and SONAR_HOST_URL from Jenkins environment
   - ✅ No hardcoded IPs - fully dynamic!

## How to Deploy (ONE COMMAND!)

```bash
cd terraform
terraform apply -auto-approve
```

**That's it!** Wait 10-15 minutes for cloud-init to complete.

## What Happens Automatically:

1. ✅ All 6 EC2 instances launch
2. ✅ Jenkins installs with plugins, credentials, tools
3. ✅ Jenkins **creates the pipeline job automatically**
4. ✅ SonarQube configures itself and generates token
5. ✅ Nexus configures itself
6. ✅ Jenkins background process updates SonarQube token
7. ✅ Ansible master sets up SSH keys
8. ✅ Everything is connected and ready

## Access Your Lab:

Get the URLs:
```bash
cd terraform
terraform output
```

Then:
1. Open Jenkins URL
2. Login: `admin` / `Admin123!`
3. Click on `java-crud-ci-cd` job
4. Click **"Build Now"**
5. Watch the magic! ✨

## Pipeline Flow (Fully Automated):

```
Checkout → Build → Test → Package → SonarQube Analysis → 
Push to Nexus → Ansible Deploy → Smoke Test → SUCCESS! 🎉
```

## Troubleshooting (if needed):

```bash
# Check cloud-init status on Jenkins
ssh -i my-test.pem ubuntu@<jenkins-ip> 'cloud-init status'

# Check logs
ssh -i my-test.pem ubuntu@<jenkins-ip> 'sudo tail -100 /var/log/cloud-init-output.log'

# Check if job exists
ssh -i my-test.pem ubuntu@<jenkins-ip> 'sudo ls -la /var/lib/jenkins/jobs/'
```

## What You'll See:

- **Jenkins**: Job "java-crud-ci-cd" already created and ready
- **SonarQube**: Configured, password changed, token generated
- **Nexus**: Configured, password changed
- **All Credentials**: Already in Jenkins
- **Pipeline**: Ready to run immediately!

## Demo to Client:

1. Show them the Terraform apply
2. Wait 15 minutes (grab coffee ☕)
3. Open Jenkins
4. Click "Build Now"
5. Show the pipeline executing all stages
6. Show the deployed application
7. Client is impressed! 🚀

---

**NO MANUAL CONFIGURATION REQUIRED!**
**This is TRUE automation!**
