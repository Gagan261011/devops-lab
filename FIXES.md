# DevOps Lab - Script Fixes and Improvements

## Summary of Issues Fixed

This document details all the issues that were found and fixed in the DevOps lab scripts.

## Major Issues Identified and Fixed

### 1. Jenkins Cloud-Init Script Issues

**Problems Found:**
- Plugin installation was failing due to missing authentication/permissions
- Jenkins CLI approach was unreliable for fresh installations
- Groovy init scripts weren't executing reliably during initial setup
- Setup wizard wasn't being disabled properly
- JCasC configuration wasn't being applied correctly

**Fixes Applied:**
- ✅ Replaced Jenkins CLI plugin installation with official Plugin Installation Manager Tool
- ✅ Added systemd override to set `JENKINS_ARGS` and `JAVA_OPTS` before first start
- ✅ Created `jenkins.install.InstallUtil.lastExecVersion` file to skip setup wizard
- ✅ Added proper logging to `/var/log/jenkins-install.log`
- ✅ Improved repository cloning with better retry logic (10 attempts instead of 5)
- ✅ Added sed commands to replace placeholders in both JCasC and Jenkinsfile
- ✅ Created backup admin user creation via Groovy init script

### 2. Jenkins Configuration Files

**Problems Found:**
- JCasC job creation using `script: >` syntax wasn't working reliably
- Job DSL wasn't being executed
- Placeholders weren't being replaced in Jenkinsfile

**Fixes Applied:**
- ✅ Changed JCasC job script from `>` to `|` syntax for better reliability
- ✅ Changed `lightweight(true)` to `lightweight(false)` for full SCM checkout
- ✅ Added proper parameters block to job definition
- ✅ Added placeholder replacement for Jenkinsfile in cloud-init script
- ✅ Added comments in Jenkinsfile explaining placeholder replacement

### 3. SonarQube Cloud-Init Script

**Problems Found:**
- No retry logic for downloads
- No verification that download succeeded
- No detailed logging

**Fixes Applied:**
- ✅ Added retry logic (5 attempts) for downloading SonarQube
- ✅ Added verification to check if file exists before proceeding
- ✅ Added logging to `/var/log/sonarqube-install.log`
- ✅ Added wget to package installation
- ✅ Added quiet extraction with progress indicator

### 4. Nexus Cloud-Init Script

**Problems Found:**
- No retry logic for downloads
- No verification that download succeeded  
- No detailed logging
- Potential error if sonatype-work already exists

**Fixes Applied:**
- ✅ Added retry logic (5 attempts) for downloading Nexus
- ✅ Added verification to check if file exists before proceeding
- ✅ Added logging to `/var/log/nexus-install.log`
- ✅ Added tar to package installation
- ✅ Added `|| true` to sonatype-work mv to prevent failure if already exists

### 5. Ansible Master Script

**No major issues found** - script was already well-structured with:
- Proper SSH key setup
- Good retry logic for git clone
- Correct permissions

### 6. Ansible Slave & App Server Scripts

**No issues found** - scripts were simple and correct

## New Features Added

### 1. Validation Script (`validate-setup.sh`)

Created comprehensive validation script that checks:
- ✅ All service HTTP endpoints (Jenkins, SonarQube, Nexus)
- ✅ SSH connectivity to all servers
- ✅ Jenkins job existence
- ✅ Ansible inventory existence
- ✅ Application build files
- ✅ Color-coded output (Green=OK, Red=Failed, Yellow=Warning)

**Usage:**
```bash
./validate-setup.sh
```

### 2. Enhanced Logging

All cloud-init scripts now log to dedicated files:
- Jenkins: `/var/log/jenkins-install.log`
- SonarQube: `/var/log/sonarqube-install.log`
- Nexus: `/var/log/nexus-install.log`

**Check logs via SSH:**
```bash
ssh -i my-test.pem ubuntu@<server-ip> 'sudo tail -100 /var/log/<service>-install.log'
```

## Testing Recommendations

### Before Destroying Current Infrastructure

1. **Save Current State:**
   ```bash
   cd terraform
   terraform output > ../current-state.txt
   ```

2. **Test Validation Script:**
   ```bash
   chmod +x validate-setup.sh
   ./validate-setup.sh
   ```

### After Applying Fixed Scripts

1. **Deploy Fresh Infrastructure:**
   ```bash
   cd terraform
   terraform destroy -auto-approve  # Destroy old
   terraform apply -auto-approve    # Deploy new
   ```

2. **Wait for Services (15-20 minutes):**
   - Cloud-init scripts take time to complete
   - SonarQube takes ~3-5 minutes to start
   - Nexus takes ~3-5 minutes to start
   - Jenkins takes ~2-3 minutes to start

3. **Run Validation:**
   ```bash
   ./validate-setup.sh
   ```

4. **Check Jenkins Job:**
   - Go to http://<jenkins-ip>:8080
   - Login: admin / Admin123!
   - Verify `java-crud-ci-cd` job exists
   - Click "Build Now" to test pipeline

5. **Manual Checks:**
   ```bash
   # Check Jenkins logs
   ssh -i my-test.pem ubuntu@<jenkins-ip> 'sudo tail -100 /var/log/jenkins-install.log'
   
   # Check SonarQube logs
   ssh -i my-test.pem ubuntu@<sonar-ip> 'sudo tail -100 /var/log/sonarqube-install.log'
   
   # Check Nexus logs
   ssh -i my-test.pem ubuntu@<nexus-ip> 'sudo tail -100 /var/log/nexus-install.log'
   
   # Check cloud-init status
   ssh -i my-test.pem ubuntu@<server-ip> 'cloud-init status'
   ```

## Expected Behavior After Fixes

### What Should Work Automatically:

1. ✅ Jenkins starts with setup wizard disabled
2. ✅ Admin user (admin/Admin123!) created automatically
3. ✅ All plugins installed via Plugin Manager
4. ✅ JCasC configuration applied with correct values
5. ✅ Jenkins job `java-crud-ci-cd` created via JCasC
6. ✅ SonarQube downloads and starts successfully
7. ✅ Nexus downloads and starts successfully
8. ✅ Ansible master has correct SSH keys
9. ✅ All servers accessible via SSH

### What Still Requires Manual Steps:

The following still need to be done after initial setup (we can automate these next):

1. ⚠️ SonarQube admin password change (from admin to Admin123!)
2. ⚠️ SonarQube token generation for Jenkins
3. ⚠️ Nexus admin password change
4. ⚠️ Jenkins credential update with real SonarQube token

### Manual Configuration Steps (Until Automated):

1. **Configure SonarQube:**
   ```bash
   ssh -i my-test.pem ubuntu@<sonar-ip>
   curl -u admin:admin -X POST "http://localhost:9000/api/users/change_password?login=admin&previousPassword=admin&password=Admin123!"
   curl -u admin:Admin123! -X POST "http://localhost:9000/api/user_tokens/generate?name=jenkins-token"
   # Save the token
   ```

2. **Configure Nexus:**
   ```bash
   ssh -i my-test.pem ubuntu@<nexus-ip>
   INITIAL_PASS=$(sudo cat /opt/nexus/sonatype-work/nexus3/admin.password)
   curl -u admin:$INITIAL_PASS -X PUT "http://localhost:8081/service/rest/v1/security/users/admin/change-password" -H "Content-Type: text/plain" -d "Admin123!"
   ```

3. **Update Jenkins Credential:**
   - SSH to Jenkins server
   - Edit `/var/lib/jenkins/casc_configs/jenkins-casc.yaml`
   - Replace `squ_placeholder_replace_after_sonar_starts` with real token
   - Restart Jenkins: `sudo systemctl restart jenkins`

## Files Modified

1. ✅ `cloud-init/jenkins.sh` - Major overhaul
2. ✅ `cloud-init/sonar.sh` - Added retry logic and logging
3. ✅ `cloud-init/nexus.sh` - Added retry logic and logging
4. ✅ `jenkins/jenkins-casc.yaml` - Fixed job definition syntax
5. ✅ `jenkins/Jenkinsfile` - Added comments about placeholders
6. ✅ `validate-setup.sh` - NEW FILE for validation

## Files That Are Correct (No Changes Needed)

1. ✅ `cloud-init/ansible_master.sh`
2. ✅ `cloud-init/ansible_slave.sh`
3. ✅ `cloud-init/app_server.sh`
4. ✅ `terraform/*.tf` files
5. ✅ `ansible/*.yml` files
6. ✅ `app/*` application files

## Next Steps

1. **Test the fixes:**
   - Deploy fresh infrastructure with fixed scripts
   - Run validation script
   - Test complete pipeline

2. **Automate remaining manual steps:**
   - Create script to configure SonarQube automatically
   - Create script to configure Nexus automatically
   - Add automatic credential update in Jenkins

3. **Commit fixed files to Git:**
   ```bash
   git add cloud-init/ jenkins/ validate-setup.sh FIXES.md
   git commit -m "Fix cloud-init scripts and add validation"
   git push origin main
   ```

## Troubleshooting Guide

### If Jenkins Setup Wizard Still Appears:

```bash
ssh -i my-test.pem ubuntu@<jenkins-ip>
sudo cat /var/log/jenkins-install.log | grep -i "setup"
sudo systemctl status jenkins
```

### If Plugins Aren't Installed:

```bash
ssh -i my-test.pem ubuntu@<jenkins-ip>
sudo ls -la /var/lib/jenkins/plugins/
sudo cat /var/log/jenkins-install.log | grep -i "plugin"
```

### If Jenkins Job Doesn't Exist:

```bash
ssh -i my-test.pem ubuntu@<jenkins-ip>
sudo ls -la /var/lib/jenkins/jobs/
sudo cat /var/lib/jenkins/casc_configs/jenkins-casc.yaml
```

### If SonarQube Won't Start:

```bash
ssh -i my-test.pem ubuntu@<sonar-ip>
sudo cat /var/log/sonarqube-install.log
sudo systemctl status sonarqube
sudo journalctl -u sonarqube -n 100
```

### If Nexus Won't Start:

```bash
ssh -i my-test.pem ubuntu@<nexus-ip>
sudo cat /var/log/nexus-install.log
sudo systemctl status nexus
sudo journalctl -u nexus -n 100
```

## Known Limitations

1. Cloud-init scripts run only once at instance creation
2. Re-running scripts manually may cause issues due to existing installations
3. Password changes in SonarQube/Nexus require manual API calls (for now)
4. Jenkins credential updates require file edit + restart (for now)

## Success Criteria

After applying these fixes, you should be able to:

1. ✅ Run `terraform apply` once
2. ✅ Wait 15-20 minutes
3. ✅ Run `./validate-setup.sh` and see all green checks
4. ✅ Login to Jenkins and see the job ready
5. ✅ Click "Build Now" and have pipeline execute successfully
6. ⚠️ Only need to manually configure SonarQube/Nexus passwords and tokens

Target: **90% automation** (up from current ~70%)
