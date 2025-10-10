// ================================
// Scripted Jenkins Pipeline for Salesforce Metadata Backup & Deploy
// ================================
// ✅ Features:
// - Red * for mandatory fields
// - BranchName parameter added
// - Automatic backup creation
// - Multi-tag XML update
// - Git commit & push to selected branch
// ================================

node {

    // -------------------------------
    // Build Parameters (Red * for mandatory fields)
    // -------------------------------
    properties([
        parameters([
            string(name: 'OrgAlias', defaultValue: '', description: '<font color="red">*</font> Salesforce Org Alias / Username'),
            string(name: 'OrgUrl', defaultValue: 'https://login.salesforce.com', description: '<font color="red">*</font> Salesforce Org URL (https://login.salesforce.com or https://test.salesforce.com)'),
            string(name: 'BranchName', defaultValue: 'dev', description: '<font color="red">*</font> Git Branch Name to Commit & Push Changes'),
            string(name: 'XML_PATH', defaultValue: 'force-app/main/default/settings/Security.settings-meta.xml', description: '<font color="red">*</font> Path to XML file relative to repo root'),
            text(name: 'TagNames', defaultValue: 'Name,Description', description: '<font color="red">*</font> Comma-separated XML Tag Names (e.g., Name,Description,IsActive)'),
            text(name: 'TagValues', defaultValue: 'UpdatedName,UpdatedDesc', description: '<font color="red">*</font> Comma-separated XML Tag Values (e.g., Dev,Test,True)'),
            string(name: 'BackupFolder', defaultValue: 'backups', description: 'Backup folder name (default: backups)')
        ])
    ])

    // -------------------------------
    // Validate Parameters
    // -------------------------------
    stage('Validate Parameters') {
        echo "\n==================== PARAMETER VALIDATION ===================="
        def missingParams = []

        if (!params.OrgAlias?.trim()) missingParams << 'OrgAlias'
        if (!params.OrgUrl?.trim()) missingParams << 'OrgUrl'
        if (!params.BranchName?.trim()) missingParams << 'BranchName'
        if (!params.XML_PATH?.trim()) missingParams << 'XML_PATH'
        if (!params.TagNames?.trim()) missingParams << 'TagNames'
        if (!params.TagValues?.trim()) missingParams << 'TagValues'

        if (missingParams) {
            echo "\033[1;31m❌ Missing mandatory parameters: ${missingParams.join(', ')}\033[0m"
            error("Build stopped: Please provide values for ${missingParams.join(', ')}.")
        }

        // Assign trimmed values
        ORG_ALIAS   = params.OrgAlias.trim()
        ORG_URL     = params.OrgUrl.trim()
        BRANCH_NAME = params.BranchName.trim()
        XML_PATH    = params.XML_PATH.trim()
        TAG_NAMES   = params.TagNames.trim()
        TAG_VALUES  = params.TagValues.trim()
        BACKUP_DIR  = params.BackupFolder?.trim() ?: 'backups'

        // Resolve path relative to workspace
        if (!XML_PATH.startsWith('/') && !XML_PATH.matches('^[A-Za-z]:.*')) {
            XML_PATH = "${env.WORKSPACE}/${XML_PATH}"
        }
        if (!isUnix()) {
            XML_PATH = XML_PATH.replace('/', '\\')
        }

        echo "✅ Parameters validated successfully."
        echo "Resolved XML_PATH: ${XML_PATH}"
    }

    // -------------------------------
    // Pre-check: Validate File Exists
    // -------------------------------
    stage('Pre-Check XML File Exists') {
        def exists = fileExists(XML_PATH)
        if (!exists) {
            echo "\033[1;31m❌ ERROR: XML file not found at ${XML_PATH}\033[0m"
            error("File missing: Please check the XML_PATH provided.")
        } else {
            echo "✅ XML file exists: ${XML_PATH}"
        }
    }

    // -------------------------------
    // Create Backup Folder and Copy File
    // -------------------------------
    stage('Backup XML File') {
        def timestamp = new Date().format('yyyyMMdd_HHmmss')
        def backupPath = "${BACKUP_DIR}/backup_${timestamp}"

        echo "📦 Creating backup folder: ${backupPath}"

        try {
            if (isUnix()) {
                sh """
                    mkdir -p "${backupPath}"
                    cp "${XML_PATH}" "${backupPath}/"
                """
            } else {
                bat """
                    if not exist "${backupPath}" mkdir "${backupPath}"
                    copy /Y "${XML_PATH}" "${backupPath}\\"
                """
            }
            echo "✅ Backup completed successfully at: ${backupPath}"
        } catch (err) {
            echo "\033[1;31m❌ Error during backup: ${err}\033[0m"
            error("Backup failed. Verify XML_PATH and permissions.")
        }
    }

    // -------------------------------
    // Update XML File with Tag Values
    // -------------------------------
    stage('Update XML Tags') {
        echo "🛠 Updating XML tags in file: ${XML_PATH}"

        def tagNamesList  = TAG_NAMES.split(',')
        def tagValuesList = TAG_VALUES.split(',')

        if (tagNamesList.size() != tagValuesList.size()) {
            error("❌ Mismatch: TagNames count (${tagNamesList.size()}) ≠ TagValues count (${tagValuesList.size()})")
        }

        for (int i = 0; i < tagNamesList.size(); i++) {
            def tag = tagNamesList[i].trim()
            def val = tagValuesList[i].trim()
            echo "🔄 Updating <${tag}> → ${val}"

            if (isUnix()) {
                sh """
                    sed -i 's#<${tag}>.*</${tag}>#<${tag}>${val}</${tag}>#g' "${XML_PATH}" || true
                """
            } else {
                bat """
                    powershell -Command "(Get-Content '${XML_PATH}') -replace '<${tag}>.*?</${tag}>', '<${tag}>${val}</${tag}>' | Set-Content '${XML_PATH}'"
                """
            }
        }

        echo "✅ XML tags updated successfully."
    }

    // -------------------------------
    // Git Commit & Push to Selected Branch
    // -------------------------------
    stage('Commit & Push to GitHub') {
        echo "💾 Committing updated file to branch: ${BRANCH_NAME}"
        try {
            if (isUnix()) {
                sh """
                    git fetch origin
                    git checkout ${BRANCH_NAME} || git checkout -b ${BRANCH_NAME}
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git add "${XML_PATH}"
                    git commit -m "Updated XML via Jenkins Build #${env.BUILD_ID}" || echo No changes to commit
                    git push origin ${BRANCH_NAME}
                """
            } else {
                bat """
                    git fetch origin
                    git checkout ${BRANCH_NAME} || git checkout -b ${BRANCH_NAME}
                    git config user.email "jenkins@example.com"
                    git config user.name "Jenkins CI"
                    git add "${XML_PATH}"
                    git commit -m "Updated XML via Jenkins Build #${env.BUILD_ID}" || echo No changes to commit
                    git push origin ${BRANCH_NAME}
                """
            }
            echo "✅ Changes committed and pushed successfully to branch ${BRANCH_NAME}."
        } catch (err) {
            echo "⚠️ Git commit/push failed: ${err}"
        }
    }

    // -------------------------------
    // Deploy Updated Metadata to Salesforce Org
    // -------------------------------
    stage('Deploy Updated Metadata to Salesforce Org') {
        try {
            echo "🚀 Deploying updated XML file to Salesforce Org: ${ORG_ALIAS}"

            if (isUnix()) {
                sh """
                    sf project deploy start --target-org ${ORG_ALIAS} --source-dir "${XML_PATH}" --wait 10
                """
            } else {
                bat """
                    echo Deploying ${XML_PATH} to org ${ORG_ALIAS}...
                    sf project deploy start --target-org ${ORG_ALIAS} --source-dir "${XML_PATH}" --wait 10
                """
            }

            echo "✅ Deployment completed successfully."
        } catch (err) {
            echo "\033[1;31m❌ Deployment failed: ${err}\033[0m"
            error("Salesforce deployment failed.")
        }
    }

    // -------------------------------
    // Post Cleanup
    // -------------------------------
    stage('Post-Cleanup') {
        echo "🧹 Cleaning up workspace..."
        cleanWs()
    }
}
